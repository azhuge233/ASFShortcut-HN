import { HdsNavDestination, hdsMaterial } from '@kit.UIDesignKit';

import Logger from '../../common/utils/Logger';
import StyleConstants from '../../common/constants/StyleConstants';

/**
 * 页面内边距四边分别给：盘面有三种形态，一个数字表达不了（设计 §2.2）。
 *
 * 列表三页（`MorePage` / `DataManagementPage` / `AboutPage`）四边都是 `PAGE_PADDING`；
 * `ASFSettingsPage` 顶 24、其余三边 16；`EditPage` 顶 24、其余三边 20。
 */
export interface PagePadding {
    top: Length;
    right: Length;
    bottom: Length;
    left: Length;
}

/** 列表三页的形态：四边 `PAGE_PADDING`。做成常量而不是每个实例各建一份字面量 */
const DEFAULT_PAGE_PADDING: PagePadding = {
    top: StyleConstants.PAGE_PADDING,
    right: StyleConstants.PAGE_PADDING,
    bottom: StyleConstants.PAGE_PADDING,
    left: StyleConstants.PAGE_PADDING
};

/** `PagePadding` → `.padding()` 收的 `Padding`：显式转写，让对象字面量有确定的类型上下文 */
function toPadding(value: PagePadding): Padding {
    return { top: value.top, right: value.right, bottom: value.bottom, left: value.left };
}

/**
 * 滚动壳（无导航栏）：页面底 + `Scroll` + 占满视口且起始对齐的列 + 四边内边距。
 *
 * 单独拆出来是因为 `AddCommand` 只需要导航栏、滚动由 `AddCommandForm` 自管（设计 §2.2 要点 2）。
 * 这一段是改造前五个页面逐字重复的部分，属性一句不多、一句不少：
 * 列缺不得 `width` 与 `alignItems`（`Column` 的 `alignItems` 默认居中，补错方向就改版式）。
 */
@ComponentV2
export struct AppScrollShell {
    @Param contentPadding: PagePadding = DEFAULT_PAGE_PADDING;
    @Param columnSpace: number = 0;      // 列间距：MorePage / DataManagementPage 传 CARD_SPACE，其余 0
    @BuilderParam content: () => void;

    build() {
        Scroll() {
            Column({ space: this.columnSpace }) {
                this.content()
            }
            .width(StyleConstants.FULL_PERCENT)
            .constraintSize({ minHeight: StyleConstants.FULL_PERCENT })
            .justifyContent(FlexAlign.Start)
            .alignItems(HorizontalAlign.Start)
            .padding(toPadding(this.contentPadding))
        }
        .width(StyleConstants.FULL_PERCENT)
        .height(StyleConstants.FULL_PERCENT)
        // 页面底与卡面分层（需求 U11）：页面走 `background_secondary`，分组卡仍是 `comp_background_primary`
        .backgroundColor($r("sys.color.background_secondary"))
    }
}

/**
 * 页面骨架（C5）：导航栏 + 滚动壳 + 内边距，外加一个压在内容之上的覆盖层插槽。
 *
 * 这里持有四个未在盘面验证过的结构（设计 §5 第 0 步逐项验）：
 * 自定义组件内嵌 `HdsNavDestination`、双 `@BuilderParam`、`AttributeModifier` 判空写圆角（D10）、
 * 自定义组件挂通用属性（`AppInput` 调用点的外边距）。
 *
 * 返回键由本组件处理（D14）：`onReady` 里存下 `pathStack`，`onBack` 返回假就 `pop(backResult)`。
 * 六页盘上的返回串是同一个 `"Back pressed"`，所以默认值取它，五页一个传参都不用；
 * `ASFSettingsPage` 保存中要拦返回，它自己传 `onBack`。
 * 默认值不写成「返回假就啥也不做」——那样漏传一页就把返回串静默换成空串。
 */
@ComponentV2
export struct AppPage {
    @Param title: ResourceStr = '';
    @Param contentPadding: PagePadding = DEFAULT_PAGE_PADDING;
    @Param columnSpace: number = 0;
    @Param scrollable: boolean = true;   // false = 只给导航栏，内容自管滚动（AddCommand）
    @Param logTag: string = '';          // 各页自己的 LOG_TAG，日志行逐字不变
    @Param backResult: Object = 'Back pressed';
    @Event onReady: (ctx: NavDestinationContext) => void = () => {};
    @Event onBack: () => boolean = () => false;
    @BuilderParam content: () => void;

    @Builder
    emptyOverlay() {
    }

    @BuilderParam overlayContent: () => void = this.emptyOverlay;

    private pathStack: NavPathStack | undefined = undefined;

    build() {
        HdsNavDestination() {
            // 覆盖层压在滚动区之上、不随内容滚动：`DataManagementPage` 的加载蒙层就是它
            Stack({ alignContent: Alignment.Top }) {
                if (this.scrollable) {
                    AppScrollShell({ contentPadding: this.contentPadding, columnSpace: this.columnSpace }) {
                        this.content()
                    }
                } else {
                    this.content()
                }

                this.overlayContent()
            }
            .width(StyleConstants.FULL_PERCENT)
            .height(StyleConstants.FULL_PERCENT)
        }
        .titleBar({
            content: {
                title: {
                    mainTitle: this.title
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
            this.onReady(context);
        })
        .onBackPressed(() => {
            // 返回真 = 页面已消费（保存中提示）；返回假 = 本组件按盘上原串 pop
            if (this.onBack()) return true;
            this.pathStack?.pop(this.backResult);
            return true;
        })
        .onAppear(() => {
            Logger.debug(this.logTag, "Loaded!");
        })
    }
}
