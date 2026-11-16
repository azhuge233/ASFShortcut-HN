import { common } from '@kit.AbilityKit';
import { AppStorageV2 } from '@kit.ArkUI';

import Logger from '../../common/utils/Logger';
import StyleConstants from '../../common/constants/StyleConstants';
import CommonConstants from '../../common/constants/CommonConstants';
import { AppSettings, ColorMode } from '../../domain/model/AppSettings';
import CommandListViewModel from '../../viewmodel/CommandListViewModel';
import MoreViewModel, { MoreActionResult } from '../../viewmodel/MoreViewModel';
import { AppPage } from '../components/AppPage';
import { SettingEntry, SettingGroup } from '../components/SettingGroup';
import PageContext from '../common/PageContext';

@Builder
export function DataManagementPageBuilder() {
    DataManagementPage();
}

/**
 * 数据管理子页（B3）：导出、导入、清除所有指令。
 *
 * 导出 / 导入 / 清空与各自的确认框、失败分类原样从设置首页搬来（设计 §2.2），不新增 VM 方法；
 * 本页与设置首页同构装配 `MoreViewModel`，共用路由参数带来的同一个 `CommandListViewModel`，
 * 因此清空 / 导入之后主列表与卡片照旧由那条链路刷新。
 *
 * 外壳、两张分组卡、危险项那一行都来自组件（C1 / C4 / C5）；本页只剩业务方法与加载蒙层。
 */
@Entry
@ComponentV2
struct DataManagementPage {
    private LOG_TAG = '[pages/DataManagement]';

    @Local viewModel: MoreViewModel = new MoreViewModel(new CommandListViewModel());

    @Local appSettings: AppSettings = AppStorageV2.connect(AppSettings, CommonConstants.APP_STORAGE_KEY_APP_SETTINGS,
        () => new AppSettings(ColorMode.FOLLOW_SYSTEM))!;

    private uiContext = this.getUIContext();
    private context = this.uiContext.getHostContext() as common.UIAbilityContext;
    private promptAction = this.uiContext.getPromptAction();

    pathStack: NavPathStack | undefined = undefined;

    // 可逆的两条：导出 / 导入（描述进数据数组，行形态由 `SettingGroup` 给）
    private functionEntries: SettingEntry[] = [
        {
            title: $r("app.string.More_Export_Label"),
            icon: $r("sys.symbol.arrow_up_circle"),
            desc: $r("app.string.Export_Desc"),
            onTap: async () => {
                await this.export();
            }
        },
        {
            title: $r("app.string.More_Import_Label"),
            icon: $r("sys.symbol.arrow_down_circle"),
            desc: $r("app.string.Import_Desc"),
            onTap: async () => {
                await this.importConfirm();
            }
        }
    ];

    // 清除项单独成卡：危险色文字 + 二次确认（B3），与上面两条可逆操作分开
    private dangerEntries: SettingEntry[] = [
        {
            title: $r("app.string.More_Clear_Label"),
            icon: $r("sys.symbol.trash"),
            titleColor: $r("sys.color.warning"),
            onTap: async () => {
                await this.clear();
            }
        }
    ];

    async export(): Promise<void> {
        const result: MoreActionResult = await this.viewModel.export(this.context);

        if (result.ok) PageContext.alert($r("app.string.More_Export_Success"), this.promptAction);
        else if (result.cancelled) Logger.warn(this.LOG_TAG, `导出取消`);
        else {
            Logger.error(this.LOG_TAG, `导出失败, ${result.reason}`);
            PageContext.alert($r("app.string.More_Export_Failed"), this.promptAction);
        }
    }

    async import(): Promise<void> {
        const result: MoreActionResult = await this.viewModel.pickAndImport(this.context);

        if (result.ok) {
            PageContext.alert($r("app.string.More_Import_Success"), this.promptAction);
            this.pathStack?.pop("OK");
            return;
        }

        if (result.cancelled) {
            Logger.warn(this.LOG_TAG, `导入已取消`);
            return;
        }

        // 导入完成但绑定没清掉：如实报明并让用户重新绑定（X2）
        if (result.failure === 'bindings') {
            PageContext.alert($r("app.string.More_Import_Clear_Bindings_Failed"), this.promptAction);
            return;
        }

        PageContext.alert(`导入失败: ${result.reason}`, this.promptAction);
    }

    async importConfirm(): Promise<void> {
        try {
            const result = await this.promptAction.showDialog({
                title: $r("app.string.More_Import_Confirm_Title"),
                message: $r("app.string.More_Import_Confirm_Content"),
                buttons: [
                    {
                        text: $r("app.string.More_Confirm_Button_Confirm"),
                        color: $r("sys.color.font_primary")
                    },
                    {
                        text: $r("app.string.More_Confirm_Button_Cancel"),
                        color: $r("sys.color.font_primary")
                    }
                ]
            });

            if (result.index === 0) await this.import();
            else Logger.warn(this.LOG_TAG, "导入已取消");
        } catch (err) {
            if (err && (err.code === 100006 || err.message?.toLowerCase().includes('cancel'))) {
                Logger.warn(this.LOG_TAG, "用户取消对话框");
                return;
            }

            Logger.error(this.LOG_TAG, `导入确认框弹出失败`);
        }
    }

    async clear(): Promise<void> {
        try {
            const result = await this.promptAction.showDialog({
                title: $r("app.string.More_Clear_Confirm_Title"),
                message: $r("app.string.More_Clear_Confirm_Content"),
                buttons: [
                    {
                        text: $r("app.string.More_Confirm_Button_Confirm"),
                        color: $r("sys.color.font_primary")
                    },
                    {
                        text: $r("app.string.More_Confirm_Button_Cancel"),
                        color: $r("sys.color.font_primary")
                    }
                ]
            });

            if (result.index === 0) {
                const clearResult: MoreActionResult = await this.viewModel.clearAll();

                if (clearResult.ok) {
                    PageContext.alert($r("app.string.More_Clear_Success"), this.promptAction);
                    this.pathStack?.pop("Clear press");
                } else {
                    // 失败原因（含「绑定未解除」）进日志；绑定未解除时给专键提示，其余沿用通用失败文案
                    Logger.warn(this.LOG_TAG, `清除失败, 类别 ${clearResult.failure}, 原因 ${clearResult.reason}`);
                    PageContext.alert(clearResult.failure === 'bindings' ?
                        $r("app.string.More_Clear_Bindings_Failed") :
                        $r("app.string.More_Clear_Failed_Try_Again"), this.promptAction);
                }
            } else Logger.warn(this.LOG_TAG, "清除已取消");
        } catch (err) {
            if (err && (err.code === 100006 || err.message?.toLowerCase().includes('cancel'))) {
                Logger.warn(this.LOG_TAG, "用户取消对话框");
                return;
            }

            Logger.error(this.LOG_TAG, `清除失败, ${err}`);
            PageContext.alert($r("app.string.More_Clear_Failed"), this.promptAction);
        }
    }

    // 导入时显示
    // 阻止用户操作
    // 必须 `@LocalBuilder`：作为覆盖层插槽传给 `AppPage` 后，普通 `@Builder` 里的 `this` 不指向本组件
    // （实测崩在 `this.LOG_TAG`：`Cannot read property bind of undefined`）
    //
    // `isProcessing` 的判空必须留在插槽里：改造前这句在 build() 里包着 `LoadingContent()`，
    // 只把内容搬进插槽、不搬这句，蒙层就会常驻（实测：进页即显示「处理中」并糊住内容）。
    @LocalBuilder
    LoadingContent() {
        if (this.viewModel.isProcessing) {
            Stack() {
                Column()
                    .width(StyleConstants.FULL_PERCENT)
                    .height(StyleConstants.FULL_PERCENT)
                    .backgroundColor($r("app.color.transparent"))
                    .blur(StyleConstants.BLUE_LEVEL)
                    .onClick(() => {})
    
                Column() {
                    Progress({ value: 0, total: 100, type: ProgressType.Ring })
                        .width(StyleConstants.PROGRESS_WIDTH)
                        .color(Color.Blue)
                        .style({
                            strokeWidth: StyleConstants.PROGRESS_STROKE_WIDTH,
                            status: ProgressStatus.LOADING
                        })
    
                    Text($r("app.string.Index_Processing"))
                        .margin({ top: StyleConstants.MARGIN_TWENTY })
                        .fontSize(StyleConstants.PROGRESS_TEXT_FONT_SIZE)
                }
                .width(StyleConstants.FULL_PERCENT)
                .height(StyleConstants.FULL_PERCENT)
                .justifyContent(FlexAlign.Center)
                .onClick(() => {
                })
            }
            .onClick(() => {
            })
            .onAppear(() => {
                Logger.debug(this.LOG_TAG, "Blocking stack loaded!");
            })
        }
    }

    /** 页面内容：两张卡依次入列，卡间距由 `AppPage` 的 `columnSpace` 给 */
    @LocalBuilder
    pageContent() {
        SettingGroup({ entries: this.functionEntries })

        SettingGroup({ entries: this.dangerEntries })
    }

    build() {
        // `@Entry` 的 build 根节点必须是容器组件，自定义组件不能当根，所以包一层占满视口的 `Column`
        Column() {
            AppPage({
                title: $r("app.string.DataManagement_Title"),
                logTag: this.LOG_TAG,
                columnSpace: StyleConstants.CARD_SPACE,
                content: this.pageContent,
                // 加载蒙层压在滚动区之上、不随内容滚动
                overlayContent: this.LoadingContent,
                onReady: (context: NavDestinationContext) => {
                    this.pathStack = context.pathStack;

                    // 与设置首页同构装配：同一份列表 VM，`attachSettings` 不缺席
                    const param: CommandListViewModel = context.pathInfo.param as CommandListViewModel;
                    if (param instanceof CommandListViewModel) {
                        this.viewModel = new MoreViewModel(param);
                    } else {
                        Logger.warn(this.LOG_TAG, `未收到列表 VM，保留占位实例`);
                    }

                    this.viewModel.attachSettings(this.appSettings);
                }
            })
        }
        .width(StyleConstants.FULL_PERCENT)
        .height(StyleConstants.FULL_PERCENT)
    }
}
