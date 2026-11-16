import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { AppStorageV2 } from '@kit.ArkUI';

import Logger from '../../common/utils/Logger';
import StyleConstants from '../../common/constants/StyleConstants';
import CommonConstants from '../../common/constants/CommonConstants';
import { colorModeOptions, toDomainColorMode, toPlatformColorMode } from '../../common/utils/ColorModeMapper';
import { AppSettings, ColorMode } from '../../domain/model/AppSettings';
import CommandListViewModel from '../../viewmodel/CommandListViewModel';
import MoreViewModel from '../../viewmodel/MoreViewModel';
import PageContext from '../common/PageContext';
import { AppCard } from '../components/AppCard';
import { AppPage } from '../components/AppPage';
import { AppSelect } from '../components/AppSelect';
import { SettingEntry, SettingGroup } from '../components/SettingGroup';
import { SettingRow } from '../components/SettingRow';

@Builder
export function MorePageBuilder() {
    MorePage();
}

/**
 * 设置首页（B1 / B2 / B5 / B6）：只绑定 `MoreViewModel`（设计 §2.2）。
 *
 * 页面自留：导航栈、列表 VM 字段、窗口上下文、三张入口表；行与卡的样式全部来自组件。
 * 导出 / 导入 / 清空随职责搬到 `DataManagementPage`，版本号随 `readVersion` 搬到 `AboutPage`；
 * 两个子页各新装配一个 `MoreViewModel`，共用本页从路由参数收到的同一个 `CommandListViewModel`。
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

    // 路由参数带来的主列表 VM：`MoreViewModel.list` 是私有字段、无 getter，子页只能从这里取（设计 §2.2）
    private listVm: CommandListViewModel = new CommandListViewModel();

    pathStack: NavPathStack | undefined = undefined;

    // 三张入口表：一条设置项 = 一个对象字面量，新增一项只写一行（AC3）
    // 三张表都是子页面入口，每条都带右侧箭头（本批 D5）；颜色模式行不是入口，不加箭头
    private settingsEntries: SettingEntry[] = [
        {
            title: $r("app.string.More_Settings_Label"),
            icon: $r("sys.symbol.gearshape"),
            desc: $r("app.string.ASF_Settings_Desc"),
            showArrow: true,
            onTap: () => {
                this.pathStack?.pushPath({
                        name: "ASFSettingsPage",
                        onPop: (popInfo) => {
                            PageContext.returnFromSubPage(popInfo);
                        }
                    }
                );
            }
        }
    ];

    private dataEntries: SettingEntry[] = [
        {
            title: $r("app.string.DataManagement_Title"),
            icon: $r("sys.symbol.doc_plaintext"),
            showArrow: true,
            onTap: () => {
                this.openDataManagement();
            }
        },
    ];

    private aboutEntries: SettingEntry[] = [
        {
            title: $r("app.string.About_Title"),
            icon: $r("sys.symbol.info_circle"),
            showArrow: true,
            onTap: () => {
                this.openAbout();
            }
        }
    ];

    /** 颜色模式三档的显示文字：`AppSelect` 只收文字，档位语义留在本页 */
    private get colorModeLabels(): ResourceStr[] {
        const labels: ResourceStr[] = [];
        for (const option of colorModeOptions) {
            labels.push(option.label);
        }
        return labels;
    }

    /** 当前档的下标：与改造前颜色模式行同一条判据（认不出时回第一档） */
    private get colorModeIndex(): number {
        const platformMode: ConfigurationConstant.ColorMode = toPlatformColorMode(this.viewModel.colorMode);
        for (let index = 0; index < colorModeOptions.length; index++) {
            if (colorModeOptions[index].mode === platformMode) return index;
        }
        return 0;
    }

    /** 进数据管理子页：把列表 VM 原样转发，子页据此装配自己的 `MoreViewModel` */
    private openDataManagement(): void {
        this.pathStack?.pushPath({
            name: "DataManagementPage",
            param: this.listVm,
            onPop: (popInfo) => {
                PageContext.returnFromSubPage(popInfo);
            }
        });
    }

    /** 进关于子页：同上 */
    private openAbout(): void {
        this.pathStack?.pushPath({
            name: "AboutPage",
            param: this.listVm,
            onPop: (popInfo) => {
                PageContext.returnFromSubPage(popInfo);
            }
        });
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

    /**
     * 颜色模式组：行就地选择、不跳页，右侧带控件插槽（C1 的「控件」一类只有这一个真实消费者）。
     *
     * 不经 `SettingGroup`（那张卡只吃数据数组，D13），在页内用 `AppCard` + `SettingRow` 装配。
     * 整行不挂点击：改造前该行只有右侧 `Select` 可点，`interactive: false` 保持这个点击区域。
     */
    @LocalBuilder
    colorModeGroup() {
        AppCard() {
            SettingRow({
                title: $r("app.string.Color_Mode_Settings_Title"),
                icon: $r("sys.symbol.brush"),
                desc: $r("app.string.Color_Mode_Desc"),
                // 该行标题盘上没有字色一句，传 null 保持原色（补 `font_primary` 会把灰字变白）
                titleColor: null,
                interactive: false,
                trailing: this.colorModeSelect
            })
        }
    }

    @LocalBuilder
    colorModeSelect() {
        AppSelect({
            options: this.colorModeLabels,
            selectedIndex: this.colorModeIndex,
            onSelect: (index: number) => {
                const platformMode: ConfigurationConstant.ColorMode = colorModeOptions[index].mode;
                const domainMode: ColorMode | null = toDomainColorMode(platformMode);
                if (domainMode === null) return;
                this.applyColorMode(platformMode, domainMode);
            }
        })
    }

    /** 页面内容：四张卡依次入列，卡间距由 `AppPage` 的 `columnSpace` 给 */
    @LocalBuilder
    pageContent() {
        SettingGroup({ entries: this.settingsEntries })

        this.colorModeGroup()

        SettingGroup({ entries: this.dataEntries })

        SettingGroup({ entries: this.aboutEntries })
    }

    build() {
        // `@Entry` 的 build 根节点必须是容器组件，自定义组件不能当根，所以包一层占满视口的 `Column`
        Column() {
            AppPage({
                title: $r("app.string.More_Title"),
                logTag: this.LOG_TAG,
                columnSpace: StyleConstants.CARD_SPACE,
                content: this.pageContent,
                onReady: (context: NavDestinationContext) => {
                    this.pathStack = context.pathStack;

                    // 路由参数带的是主列表的 VM：子页要的是同一个实例，先存下来再转发（设计 §2.2）
                    const param: CommandListViewModel = context.pathInfo.param as CommandListViewModel;
                    if (param instanceof CommandListViewModel) {
                        this.listVm = param;
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
