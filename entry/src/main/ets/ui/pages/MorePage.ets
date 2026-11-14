import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { AppStorageV2 } from '@kit.ArkUI';
import { HdsNavDestination, hdsMaterial } from '@kit.UIDesignKit';
import bundleManager from '@ohos.bundle.bundleManager';

import Logger from '../../common/utils/Logger';
import StyleConstants from '../../common/constants/StyleConstants';
import CommonConstants from '../../common/constants/CommonConstants';
import { toDomainColorMode, toPlatformColorMode } from '../../common/utils/ColorModeMapper';
import { AppSettings, ColorMode } from '../../domain/model/AppSettings';
import { ColorModeRow, colorModeOptions } from '../components/ColorModeRow';
import CommandListViewModel from '../../viewmodel/CommandListViewModel';
import MoreViewModel, { MoreActionResult } from '../../viewmodel/MoreViewModel';
import { MoreMenuItem } from '../components/MoreMenuItem';
import PageContext from '../common/PageContext';

@Builder
export function MorePageBuilder() {
    MorePage();
}

/**
 * 更多功能页（B3 重写）：只绑定 `MoreViewModel`（设计 §2.4.4 的 `MorePage` 行）。
 *
 * 页面自留：导航栈、提示、窗口上下文、三张菜单项表、`ColorModeRow` 的选项表。
 * 导出 / 导入 / 清空 / 版本号 / 颜色模式都经 VM；页面不直连数据层（设置、文件存取、卡片发布
 * 都在 VM 背后的端口后面），也不再自己拼备份 JSON。
 *
 * 颜色模式两段分工（§2.9）：VM 发意图（写共享 `AppSettings` + 落盘），
 * 平台调用 `getApplicationContext().setColorMode` 留在页面。
 */
@Entry
@ComponentV2
struct MorePage {
    private LOG_TAG = '[pages/More]';

    @Local viewModel: MoreViewModel = new MoreViewModel(new CommandListViewModel());

    @Local appSettings: AppSettings = AppStorageV2.connect(AppSettings, CommonConstants.APP_STORAGE_KEY_APP_SETTINGS,
        () => new AppSettings(ColorMode.FOLLOW_SYSTEM))!;

    private uiContext = this.getUIContext();
    private context = this.uiContext.getHostContext() as common.UIAbilityContext;
    private promptAction = this.uiContext.getPromptAction();

    pathStack: NavPathStack | undefined = undefined;

    private settingsEntries: Array<[Resource, Resource, Resource | null, () => void | Promise<void>]> = [
      [
        $r("app.string.More_Settings_Label"), $r("app.media.gearshape"), $r("app.string.ASF_Settings_Desc"),
          () => {
            this.pathStack?.pushPath(
              {
                  name: "ASFSettingsPage",
                  onPop: (popInfo) => {
                      PageContext.returnFromSubPage(popInfo);
                  }
              }
          );}
      ]
    ];

    private functionEntries: Array<[Resource, Resource, Resource | null, () => void | Promise<void>]> = [
      [ $r("app.string.More_Export_Label"), $r("app.media.arrow_up_circle"), $r("app.string.Export_Desc"), async () => { await this.export(); } ],
      [ $r("app.string.More_Import_Label"), $r("app.media.arrow_down_circle"), $r("app.string.Import_Desc"), async () => { await this.importConfirm(); } ]
    ];

    private otherEntries: Array<[Resource, Resource, Resource | null, () => void | Promise<void>]> = [
      [ $r("app.string.More_Clear_Label"), $r("app.media.clean"), null, async () => { await this.clear(); } ]
    ];

    /** 版本号由页面读 `bundleManager` 后交给 VM（平台调用不进 VM，§2.4.1） */
    private readVersion(): void {
        try {
            let bundleInfo = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
            this.viewModel.setVersion(bundleInfo.versionName, bundleInfo.versionCode.toString());
        } catch (error) {
            Logger.error(this.LOG_TAG, `同步获取失败: ${error.message}`);
        }
    }

    /** 选中即生效：VM 写设置并落盘，页面接着应用平台颜色模式；同值不做任何事（1.7.1 同一判据） */
    private async applyColorMode(platformMode: ConfigurationConstant.ColorMode,
        domainMode: ColorMode): Promise<void> {
        if (this.viewModel.colorMode === domainMode) return;

        await this.viewModel.selectColorMode(domainMode);

        try {
            this.context.getApplicationContext().setColorMode(platformMode);
            Logger.debug(this.LOG_TAG, `窗口颜色设置: ${platformMode}`);
        } catch (err) {
            Logger.error(this.LOG_TAG, `设置窗口颜色模式失败, ${err}`);
        }
    }

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

            Logger.error(this.LOG_TAG, `删除确认框弹出失败`);
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
    @Builder
    LoadingContent() {
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

    @Builder
    EntryGroup(entries: Array<[Resource, Resource, Resource | null, () => void | Promise<void>]>) {
        Column() {
            ForEach(entries, (item: [Resource, Resource, Resource | null, () => void | Promise<void>]) => {
                MoreMenuItem(
                    {
                        menuTitleText: item[0],
                        menuIcon: item[1],
                        menuDescText: item[2],
                        doJob: item[3]
                    }
                )
            }, (item: [Resource, Resource, Resource | null, () => void | Promise<void>], index: number) => index.toString())
        }
        .width(StyleConstants.FULL_PERCENT)
    }

    @Builder
    EntryDivider() {
        Divider()
            .lineCap(LineCapStyle.Round)
            .strokeWidth(StyleConstants.MORE_MENU_DIVIDER_STROKE_WIDTH)
            .width(StyleConstants.NINETY_PERCENT)
    }

    @Builder
    VersionFooter() {
        Text(`${this.viewModel.versionName} (${this.viewModel.versionCode})`)
            .width(StyleConstants.FULL_PERCENT)
            .fontColor(Color.Grey)
            .fontSize(StyleConstants.MORE_MENU_VERSION_FONT_SIZE)
            .alignSelf(ItemAlign.End)
            .textAlign(TextAlign.Center)
    }

    build() {
        HdsNavDestination() {
            Stack({ alignContent: Alignment.Top }) {
                Column() {
                    Column() {
                        this.EntryGroup(this.settingsEntries);

                        // 颜色模式行就地选择、不跳页，形状与 `MoreMenuItem` 不同，所以不入 `settingsEntries`（那张表只装跳转行）。
                        ColorModeRow({
                            icon: $r("app.media.brush"),
                            label: $r("app.string.Color_Mode_Settings_Title"),
                            desc: $r("app.string.Color_Mode_Desc"),
                            options: colorModeOptions,
                            currentMode: toPlatformColorMode(this.viewModel.colorMode),
                            onSelectMode: (mode: ConfigurationConstant.ColorMode) => {
                                const domainMode: ColorMode | null = toDomainColorMode(mode);
                                if (domainMode === null) return;
                                this.applyColorMode(mode, domainMode);
                            }
                        })

                        this.EntryDivider();

                        this.EntryGroup(this.functionEntries);

                        this.EntryDivider();

                        this.EntryGroup(this.otherEntries);
                    }
                    .height(StyleConstants.FULL_PERCENT)
                    .width(StyleConstants.FULL_PERCENT)

                    this.VersionFooter();
                }
                .height(StyleConstants.FULL_PERCENT)
                .width(StyleConstants.FULL_PERCENT)

                if (this.viewModel.isProcessing) {
                    this.LoadingContent();
                }
            }
        }
        .titleBar({
            content: {
                title: {
                    mainTitle: $r("app.string.More_Title")
                }
            },
            style: {
                systemMaterialEffect: {
                    materialType: hdsMaterial.MaterialType.ADAPTIVE,
                    materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
                }
            },
            enableComponentSafeArea: true
        })
        .height(StyleConstants.FULL_PERCENT)
        .width(StyleConstants.FULL_PERCENT)
        .onReady((context: NavDestinationContext) => {
            this.pathStack = context.pathStack;

            // 路由参数带的是主列表的 VM：导入 / 清空要落库并刷新列表与卡片，走的就是它
            const param: CommandListViewModel = context.pathInfo.param as CommandListViewModel;
            if (param instanceof CommandListViewModel) {
                this.viewModel = new MoreViewModel(param);
            } else {
                Logger.warn(this.LOG_TAG, `未收到列表 VM，保留占位实例`);
            }

            this.viewModel.attachSettings(this.appSettings);
            this.readVersion();
        })
        .onBackPressed(() => {
            this.pathStack?.pop("Back pressed");
            return true;
        })
        .onAppear(() => {
            Logger.debug(this.LOG_TAG, "Loaded!");
        })
    }
}
