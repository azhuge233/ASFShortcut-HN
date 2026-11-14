import { common } from '@kit.AbilityKit';
import { HdsNavigation, HdsNavigationTitleMode, ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit';

import StyleConstants from '../../common/constants/StyleConstants';
import Logger from '../../common/utils/Logger';
import CommonConstants from '../../common/constants/CommonConstants';
import PageContext from '../common/PageContext';
import CommandFormEditViewModel from '../../viewmodel/CommandFormEditViewModel';
import { CommandEntryViewModel } from '../../viewmodel/CommandEntryViewModel';

/**
 * 单指令卡的编辑页（B3 重写）：只绑定 `CommandFormEditViewModel`。
 * 页面自留上下文（关窗）、滚动对象、提示与勾选呈现；绑定落盘与卡片写入都在 VM 里。
 * 单卡只允许一个选中，这个「只许一个」的规则留在页面（设计 §2.4.2 的 `CommandFormEditViewModel` 行）。
 */
@Entry
@ComponentV2
struct SingleCommandFormEdit {
    private LOG_TAG = "[pages/SingleCommandFormEdit]";

    @Local viewModel: CommandFormEditViewModel = new CommandFormEditViewModel();

    private context = this.getUIContext().getHostContext() as common.UIAbilityContext;

    private scrollerForList: ListScroller = new ListScroller();

    private formID: string = '';

    async onPageShow(): Promise<void> {
        this.formID = this.readFormID();
        await this.viewModel.init(this.formID);
    }

    onPageHide(): void {
        PageContext.closeApplication(this.LOG_TAG, this.context);
    }

    private readFormID(): string {
        if (!AppStorage.has(CommonConstants.APP_STORAGE_KEY_FORM_ID)) return '';

        const formIDParam: string | undefined = AppStorage.get(CommonConstants.APP_STORAGE_KEY_FORM_ID);
        if (!formIDParam) return '';

        Logger.debug(this.LOG_TAG, `传入 formID: ${formIDParam}`);
        AppStorage.delete(CommonConstants.APP_STORAGE_KEY_FORM_ID);
        return formIDParam;
    }

    // 整行可选中；单卡只留一个选中项
    private toggleSelection(itemID: number): void {
        if (this.viewModel.isSelected(itemID)) {
            this.viewModel.toggleSelection(itemID);
            return;
        }

        this.viewModel.selectedIDs = [];
        this.viewModel.toggleSelection(itemID);
    }

    private async handleConfirmClick(): Promise<void> {
        const saved: boolean = await this.viewModel.confirmSingle();
        // 保存成功后关闭页面（1.7.1 同一判据：绑定与卡片写入都成功才关）
        if (saved) PageContext.closeApplication(this.LOG_TAG, this.context);
    }

    @Builder
    LoadingContent() {
        Column() {
            LoadingProgress()
                .width(StyleConstants.LOADING_WIDTH)
                .layoutWeight(1)
        }
        .height(StyleConstants.FULL_PERCENT)
        .width(StyleConstants.FULL_PERCENT)
        .alignItems(HorizontalAlign.Center)
    }

    @Builder
    SetupNotice() {
        Column() {
            Text($r("app.string.FormEdit_No_Setup_Label"))
                .fontSize(StyleConstants.INDEX_NO_ENTRY_TITLE_FONT_SIZE)
                .fontColor(Color.Gray)
            Text($r("app.string.FormEdit_Go_To_Settings_Label"))
                .fontSize(StyleConstants.INDEX_NO_ENTRY_SECOND_TITLE_FONT_SIZE)
                .fontColor(Color.Orange)
                .margin({ top: StyleConstants.MARGIN_TEN })
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(StyleConstants.INDEX_LAYOUT_WEIGHT)
        .width(StyleConstants.FULL_PERCENT)
    }

    @Builder
    NoShortcutsNotice() {
        Column() {
            Text($r("app.string.FormEdit_No_Commands_Label"))
                .fontSize(StyleConstants.INDEX_NO_ENTRY_TITLE_FONT_SIZE)
                .fontColor(Color.Gray)
            Text($r("app.string.FormEdit_Create_First_Label"))
                .fontSize(StyleConstants.INDEX_NO_ENTRY_SECOND_TITLE_FONT_SIZE)
                .fontColor(Color.Gray)
                .margin({ top: StyleConstants.MARGIN_TEN })
            Text($r("app.string.FormEdit_Notice_Label"))
                .fontSize(StyleConstants.INDEX_NO_ENTRY_SECOND_TITLE_FONT_SIZE)
                .fontColor(Color.Orange)
                .margin({ top: StyleConstants.MARGIN_TEN })
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(StyleConstants.INDEX_LAYOUT_WEIGHT)
        .width(StyleConstants.FULL_PERCENT)
    }

    @Builder
    ConfirmButton() {
        Row() {
            Button($r('app.string.FormEdit_Confirm_Button_Label'), { type: ButtonType.Capsule })
                .width(StyleConstants.EIGHTY_PERCENT)
                .fontWeight(FontWeight.Medium)
                .enabled(this.viewModel.canConfirm())
                .onClick(async () => {
                    await this.handleConfirmClick();
                })
        }
        .width(StyleConstants.FULL_PERCENT)
        .justifyContent(FlexAlign.Center)
        .padding({
            top: StyleConstants.PADDING_SIXTEEN,
            bottom: StyleConstants.PADDING_SIXTEEN
        })
    }

    @Builder
    MainContent() {
        if (!this.viewModel.isSettingsComplete) this.SetupNotice();
        else if (!this.viewModel.hasAnyEntry) this.NoShortcutsNotice();
        else {
            Column() {
                Text($r("app.string.FormEdit_Notice_Label"))
                    .fontSize(StyleConstants.INDEX_NO_ENTRY_SECOND_TITLE_FONT_SIZE)
                    .fontColor(Color.Orange)
                    .margin({
                        top: StyleConstants.MARGIN_TEN,
                        bottom: StyleConstants.MARGIN_TEN
                    })

                List({ scroller: this.scrollerForList }) {
                    ForEach(this.viewModel.bindableEntries, (item: CommandEntryViewModel) => {
                        ListItem() {
                            Row() {
                                Column() {
                                    Text(item.nickname)
                                        .fontWeight(FontWeight.Medium)
                                        .maxLines(1)
                                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                                        .fontColor(this.viewModel.isSelected(item.id) ?
                                            $r('sys.color.interactive_active') : $r('sys.color.font_primary'))

                                    Text(item.command)
                                        .maxLines(1)
                                        .textOverflow({ overflow: TextOverflow.MARQUEE })
                                        .fontColor(this.viewModel.isSelected(item.id) ?
                                            $r('sys.color.interactive_active') : $r('sys.color.font_secondary'))
                                }
                                .width(StyleConstants.EIGHTY_PERCENT)
                                .alignItems(HorizontalAlign.Center)
                                .padding({
                                    left: StyleConstants.PADDING_TWO,
                                    right: StyleConstants.PADDING_TWO
                                })

                                Column() {
                                    Checkbox()
                                        .select(this.viewModel.isSelected(item.id))
                                        .hitTestBehavior(HitTestMode.None)
                                }
                                .width(StyleConstants.TWENTY_PERCENT)
                                .alignItems(HorizontalAlign.Center)
                            }
                            .height(StyleConstants.TEN_PERCENT)
                            .width(StyleConstants.FULL_PERCENT)
                            .borderStyle(BorderStyle.Solid)
                            .onClick(() => {
                                this.toggleSelection(item.id);
                            })
                        }
                        .margin({
                            top: StyleConstants.FIVE_PERCENT,
                            left: StyleConstants.TWO_PERCENT,
                            right: StyleConstants.TWO_PERCENT,
                            bottom: StyleConstants.FIVE_PERCENT
                        })
                    }, (item: CommandEntryViewModel) => item.id.toString())
                }
                .lanes(2)
                .alignListItem(ListItemAlign.Center)
                .padding(StyleConstants.PADDING_EIGHT)
                .layoutWeight(StyleConstants.INDEX_LAYOUT_WEIGHT)
                .height(StyleConstants.FULL_PERCENT)
                .width(StyleConstants.FULL_PERCENT)

                this.ConfirmButton();
            }
            .height(StyleConstants.FULL_PERCENT)
            .width(StyleConstants.FULL_PERCENT)
        }
    }

    build() {
        HdsNavigation() {
            if (this.viewModel.isLoading) this.LoadingContent();
            else this.MainContent();
        }
        .titleBar({
            content: {
                title: {
                    mainTitle: $r('app.string.FormEdit_Title')
                }
            },
            style: {
                scrollEffectOpts: {
                    enableScrollEffect: true,
                    scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
                },
                systemMaterialEffect: {
                    materialType: hdsMaterial.MaterialType.ADAPTIVE,
                    materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
                },
            },
            enableComponentSafeArea: true
        })
        .titleMode(HdsNavigationTitleMode.MINI)
        .bindToScrollable([this.scrollerForList])
        .hideBackButton(false)
        .height(StyleConstants.FULL_PERCENT)
        .width(StyleConstants.FULL_PERCENT)
        .onAppear(() => {
            Logger.debug(this.LOG_TAG, 'Loaded!');
        })
    }
}
