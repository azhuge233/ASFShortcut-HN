import StyleConstants from "../../common/constants/StyleConstants";

/**
 * 空态 / 错误态（C8）：主文案 + 副文案（可选）+ 动作（可选）。
 *
 * 内部三段共用那一层：列居中、占满剩余高度；标题 18 灰、副标题 14 灰且上边距 10（盘上读数）。
 *
 * **点击只挂标题文字**：加载失败那一段改造前只有那行文字可点、整块不可点；
 * `onTap` 不传时一个回调都不挂（`AppEmptyState({title})` 整块不可点），所以按有无分支写两遍 `Text`——
 * 空回调会把整块变成点击目标，点击区域随之变大。
 */
@ComponentV2
export struct AppEmptyState {
    @Param title: ResourceStr = '';
    @Param subtitle: ResourceStr | null = null;
    @Param onTap: (() => void | Promise<void>) | null = null;

    build() {
        Column() {
            if (this.onTap !== null) {
                Text(this.title)
                    .fontSize(StyleConstants.INDEX_NO_ENTRY_TITLE_FONT_SIZE)
                    .fontColor(Color.Gray)
                    .textAlign(TextAlign.Center)
                    .onClick(() => {
                        const tap: (() => void | Promise<void>) | null = this.onTap;
                        if (tap !== null) {
                            tap();
                        }
                    })
            } else {
                Text(this.title)
                    .fontSize(StyleConstants.INDEX_NO_ENTRY_TITLE_FONT_SIZE)
                    .fontColor(Color.Gray)
                    .textAlign(TextAlign.Center)
            }

            if (this.subtitle !== null) {
                Text(this.subtitle)
                    .fontSize(StyleConstants.INDEX_NO_ENTRY_SECOND_TITLE_FONT_SIZE)
                    .fontColor(Color.Gray)
                    .textAlign(TextAlign.Center)
                    .margin({ top: StyleConstants.MARGIN_TEN })
            }
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(StyleConstants.INDEX_LAYOUT_WEIGHT)
        .width(StyleConstants.FULL_PERCENT)
    }
}
