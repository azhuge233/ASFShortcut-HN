import StyleConstants from "../../common/constants/StyleConstants";

/**
 * 主列表的搜索控件（C8 / §2.9）：`Search` 六项原样搬进本件。
 *
 * 只画控件，不持状态：关键字仍在 `CommandListViewModel`，显隐仍是 `Index.isSearchVisible`。
 * 取消按钮走 `Search.searchButton`（SDK `search.d.ts`：「Clicking the search button triggers both
 * onSubmit and onClick callbacks.」），所以它仍然同时触发 `onSubmit` 与 `onClick`。
 *
 * 两串文案随控件一起搬：本件只有 `Index` 一个消费者（设计 §2.9），再开两个参数只是把同一件事拆两处。
 */
@ComponentV2
export struct AppSearchField {
    @Param value: string = '';
    @Event onChange: (value: string) => void = () => {};
    @Event onCollapse: () => void = () => {};

    build() {
        Search({
            value: this.value,
            placeholder: $r("app.string.Index_Search_Placeholder")
        })
            .width(StyleConstants.NINETY_PERCENT)
            .margin({ bottom: StyleConstants.MARGIN_FIVE })
            .searchButton($r("app.string.Index_Search_Cancel_Button"))
            .onChange((value: string) => {
                this.onChange(value);
            })
            .onSubmit((_value: string) => {
                this.onCollapse();
            })
    }
}
