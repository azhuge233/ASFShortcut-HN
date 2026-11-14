import { common } from '@kit.AbilityKit';
import { HdsNavigation, HdsNavigationTitleMode, ScrollEffectType, hdsMaterial } from '@kit.UIDesignKit';

import StyleConstants from '../../common/constants/StyleConstants';
import Logger from '../../common/utils/Logger';
import CommonConstants from '../../common/constants/CommonConstants';
import PageContext from '../common/PageContext';
import CommandFormEditViewModel, { PageHideDecision } from '../../viewmodel/CommandFormEditViewModel';
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
    private promptAction = this.getUIContext().getPromptAction();

    private scrollerForList: ListScroller = new ListScroller();

    private formID: string = '';

    // 页面是否在前台：保存失败时若已隐藏，提示留到 `onPageShow` 补（设计 §2.7）
    private pageVisible: boolean = true;

    aboutToAppear(): void {
        // 一次性参数在页面创建时读一次（设计 §2.6）：通道只读不写
        this.formID = this.readFormID();

        // 关闭动作交给 VM：保存中隐藏后保存成功，由 VM 关窗（设计 §2.7）
        this.viewModel.setCloseHandler(() => {
            PageContext.closeApplication(this.LOG_TAG, this.context);
        });
    }

    async onPageShow(): Promise<void> {
        this.pageVisible = true;
        await this.viewModel.init(this.formID);
        this.alertSaveErrorIfAny();
    }

    onPageHide(): void {
        this.pageVisible = false;

        // 保存中隐藏不关窗，等保存结果（设计 §2.7）
        const decision: PageHideDecision = this.viewModel.notifyPageHide();
        if (decision === 'close') PageContext.closeApplication(this.LOG_TAG, this.context);
    }

    // 一次性参数从本窗口通道读（设计 §2.6）：只读不写，页面不写回参数
    private readFormID(): string {
        const formIDParam: string = PageContext.readWindowParam(this.getUIContext(), CommonConstants.APP_STORAGE_KEY_FORM_ID);
        if (formIDParam === '') return '';

        Logger.debug(this.LOG_TAG, `传入 formID: ${formIDParam}`);
        return formIDParam;
    }

    private alertSaveErrorIfAny(): void {
        if (this.viewModel.consumeSaveError() === '') return;

        PageContext.alert($r('app.string.EditPage_Update_Failed_Try_Again'), this.promptAction);
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
        if (saved) {
            PageContext.closeApplication(this.LOG_TAG, this.context);
            return;
        }

        // 失败留页可重试；页面已隐藏的那次由 `onPageShow` 补提示
        if (this.pageVisible) this.alertSaveErrorIfAny();
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
