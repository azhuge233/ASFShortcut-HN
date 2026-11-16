import { common } from '@kit.AbilityKit';
import { AppStorageV2 } from '@kit.ArkUI';
import bundleManager from '@ohos.bundle.bundleManager';

import Logger from '../../common/utils/Logger';
import StyleConstants from '../../common/constants/StyleConstants';
import CommonConstants from '../../common/constants/CommonConstants';
import { AppSettings, ColorMode } from '../../domain/model/AppSettings';
import CommandListViewModel from '../../viewmodel/CommandListViewModel';
import MoreViewModel from '../../viewmodel/MoreViewModel';
import { AppCard } from '../components/AppCard';
import { AppPage } from '../components/AppPage';
import { SettingRow } from '../components/SettingRow';
import PageContext from '../common/PageContext';

@Builder
export function AboutPageBuilder() {
    AboutPage();
}

/**
 * 关于子页（B4）：版本号、作者、开源地址。
 *
 * 版本号由页面读 `bundleManager` 后交给 VM（平台调用不进 VM）：从设置首页搬来，路径不变，
 * 所以显示值始终与 `AppScope/app.json5` 一致，不写死字面量。
 * 开源地址经 `PageContext.openLink` 拉起浏览器；失败提示且页面不退出。
 *
 * 骨架（导航栏 + 滚动壳 + 内边距）由 `AppPage` 给，本页只装内容；返回键也由 `AppPage` 处理（D14）。
 */
@Entry
@ComponentV2
struct AboutPage {
    private LOG_TAG = '[pages/About]';

    @Local viewModel: MoreViewModel = new MoreViewModel(new CommandListViewModel());

    @Local appSettings: AppSettings = AppStorageV2.connect(AppSettings, CommonConstants.APP_STORAGE_KEY_APP_SETTINGS,
        () => new AppSettings(ColorMode.FOLLOW_SYSTEM))!;

    private uiContext = this.getUIContext();
    private context = this.uiContext.getHostContext() as common.UIAbilityContext;
    private promptAction = this.uiContext.getPromptAction();

    /** 版本号由页面读 `bundleManager` 后交给 VM（平台调用不进 VM，§2.4.1） */
    private readVersion(): void {
        try {
            let bundleInfo = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
            this.viewModel.setVersion(bundleInfo.versionName, bundleInfo.versionCode.toString());
        } catch (error) {
            Logger.error(this.LOG_TAG, `同步获取失败: ${error.message}`);
        }
    }

    /** 打开仓库页：失败（无浏览器 / 权限拒绝）提示并留在本页，不把失败吞成「已打开」 */
    private async openSource(): Promise<void> {
        try {
            await PageContext.openLink(CommonConstants.OPEN_SOURCE_URL, this.context);
        } catch (err) {
            Logger.error(this.LOG_TAG, `打开开源地址失败, ${err}`);
            PageContext.alert($r("app.string.About_Open_Source_Failed"), this.promptAction);
        }
    }

    /**
     * 内容插槽：必须 `@LocalBuilder` 而不是 `@Builder`。
     *
     * 普通 `@Builder` 方法作为 `@BuilderParam` 传给子组件后，调用时 `this` 不指向本组件
     * （实测崩在这类页内插槽构建器上：`Cannot read property bind of undefined`）；
     * `@LocalBuilder` 是平台为「把组件自己的构建方法交给子组件」提供的形态，`this` 仍是本组件。
     *
     * 三项都是“小字标签在上、值在下”的列内形态（`descAbove`），行与卡都来自组件：
     * 盘上这三行的 `onClick` 本来挂在**每一行**上（只有地址项在回调里判 `isLink`），所以三行都保持可点、
     * 点击区域不变；字重与行内间距是盘上无 `fontWeight`、`Column({ space: PADDING_TWO })` 的原形（U2 + `lineSpace`）。
     */
    @LocalBuilder
    contentBuilder() {
        AppCard() {
            SettingRow({
                title: `${this.viewModel.versionName} (${this.viewModel.versionCode})`,
                desc: $r("app.string.About_Version_Label"),
                descAbove: true,
                titleWeight: FontWeight.Normal,
                lineSpace: StyleConstants.PADDING_TWO
            })

            SettingRow({
                title: CommonConstants.OPEN_SOURCE_AUTHOR,
                desc: $r("app.string.About_Author_Label"),
                descAbove: true,
                titleWeight: FontWeight.Normal,
                lineSpace: StyleConstants.PADDING_TWO
            })

            SettingRow({
                title: CommonConstants.OPEN_SOURCE_URL,
                desc: $r("app.string.About_Open_Source_Label"),
                descAbove: true,
                titleWeight: FontWeight.Normal,
                lineSpace: StyleConstants.PADDING_TWO,
                titleColor: $r("sys.color.font_emphasize"),
                onTap: () => {
                    this.openSource();
                }
            })
        }
    }

    build() {
        // `@Entry` 的 build 根节点必须是容器组件，自定义组件不能当根，所以包一层占满视口的 `Column`
        Column() {
            AppPage({
                title: $r("app.string.About_Title"),
                logTag: this.LOG_TAG,
                content: this.contentBuilder,
                onReady: (context: NavDestinationContext) => {
                    // 与设置首页同构装配：同一份列表 VM，`attachSettings` 不缺席
                    const param: CommandListViewModel = context.pathInfo.param as CommandListViewModel;
                    if (param instanceof CommandListViewModel) {
                        this.viewModel = new MoreViewModel(param);
                    } else {
                        Logger.warn(this.LOG_TAG, `未收到列表 VM，保留占位实例`);
                    }

                    this.viewModel.attachSettings(this.appSettings);
                    this.readVersion();
                }
            })
        }
        .width(StyleConstants.FULL_PERCENT)
        .height(StyleConstants.FULL_PERCENT)
    }
}
