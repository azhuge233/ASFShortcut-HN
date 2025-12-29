import { common } from '@kit.AbilityKit';
import { formBindingData, formProvider } from '@kit.FormKit';

import StyleConstants from '../common/constants/StyleConstants';
import { DB } from '../common/utils/DB';
import Logger from '../common/utils/Logger';
import { PM } from '../common/utils/PM';
import CommandEntryListViewModel from '../viewmodel/CommandEntryListViewModel';
import { CommandEntryViewModel } from '../viewmodel/CommandEntryViewModel';
import FormData from '../asfcommandwidget/model/FormData';
import CommonConstants from '../common/constants/CommonConstants';

@Entry
@ComponentV2
struct FormEdit {
    private LOG_TAG = "[pages/FormEdit]";

    @Local listViewModel: CommandEntryListViewModel = new CommandEntryListViewModel();

    @Local isLoading: boolean = true;

    @Local isDBInitialized: boolean = true;

    @Local selectedID: number | null = null;
    @Local isUpdating: boolean = false;

    private context = this.getUIContext().getHostContext() as common.UIAbilityContext;

    private db = DB.getInstance();
    private pm = PM.getInstance();

    private scrollerForList: ListScroller = new ListScroller();

    private formID: string = '';

    async onPageShow(): Promise<void> {
        await this.checkSettings();
        await this.listViewModel.loadCommandEntries();

        this.handleParamsFromForm();

        this.isLoading = false;
    }

    onPageHide(): void {
        Logger.debug(this.LOG_TAG, '退出应用');
        this.closeApplication();
    }

    private closeApplication() {
        this.context.terminateSelf().catch((err: BusinessError) => {
            Logger.error(this.LOG_TAG, `关闭应用失败, ${err}`);
        });
    }

    private async checkSettings(): Promise<void> {
        const isComplete = await this.db.areSettingsComplete();
        if (!isComplete) this.isDBInitialized = false;
    }

    private trimStringForForm(str: string): string {
        return str.length > 12 ? `${str.substring(0, 9)}...` : str;
    }

    private handleParamsFromForm(): void {
        if(AppStorage.has(CommonConstants.AppStorage_KEY_FormID)) {
            const formIDParam: string | undefined = AppStorage.get(CommonConstants.AppStorage_KEY_FormID);
            if(formIDParam) {
                this.formID = formIDParam as string;
                Logger.debug(this.LOG_TAG, `传入 formID: ${formIDParam}`);
                AppStorage.delete(CommonConstants.AppStorage_KEY_FormID);
            }
        }
    }

    private handleCheckboxChange(itemId: number, isChecked: boolean): void {
        if (isChecked) {
            // 选中当前条目，清空之前的选择
            this.selectedID = itemId;
        } else if (this.selectedID === itemId) {
            // 取消选中当前已选中的条目
            this.selectedID = null;
        }
    }

    private async handleConfirmClick(): Promise<void> {
        if (!this.selectedID || this.isUpdating || !this.formID) return;

        // 查找选中的条目
        const selectedItem = this.listViewModel.commandEntries.find(
            (item: CommandEntryViewModel) => item.id === this.selectedID
        );

        if (!selectedItem) {
            Logger.error(this.LOG_TAG, '未找到选中的条目');
            return;
        }

        try {
            this.isUpdating = true;

            const formData: FormData = new FormData(this.formID, true);

            formData.shortcutID = selectedItem.id;
            formData.nickname = this.trimStringForForm(selectedItem.nickname);
            formData.command = this.trimStringForForm(selectedItem.command);

            // 持久化存储卡片绑定信息
            await this.pm.bind(this.formID, formData);

            // 创建表单绑定数据
            const formInfo: formBindingData.FormBindingData = formBindingData.createFormBindingData(formData);
            // 更新卡片
            await formProvider.updateForm(this.formID, formInfo);

            Logger.debug(this.LOG_TAG, `卡片更新成功: formID: ${this.formID}, commandId: ${selectedItem.id}`);

            // 更新成功后关闭页面
            this.closeApplication();
        } catch (error) {
            Logger.error(this.LOG_TAG, `更新卡片失败: ${error}`);
        } finally {
            this.isUpdating = false;
        }
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
            Button($r('app.string.FormEdit_Confirm_Button_Text'), { type: ButtonType.Capsule })
                .width(StyleConstants.EIGHTY_PERCENT)
                .fontWeight(FontWeight.Medium)
                .enabled(this.selectedID !== null && !this.isUpdating)
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
        if(!this.isDBInitialized) this.SetupNotice();
        else if(this.listViewModel.commandEntries.length === 0) this.NoShortcutsNotice()
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
                    ForEach(this.listViewModel.commandEntries, (item: CommandEntryViewModel) => {
                        if (item.accountInputRequired === 0 && item.idInputRequired === 0) {
                            ListItem() {
                                Row() {
                                    Column() {
                                        Text(item.nickname)
                                            .fontWeight(FontWeight.Medium)
                                            .maxLines(1)
                                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                                            .fontColor(this.selectedID === item.id ?
                                                $r('sys.color.interactive_active') : $r('sys.color.font_primary'))

                                        Text(item.command)
                                            .maxLines(1)
                                            .textOverflow({ overflow: TextOverflow.MARQUEE })
                                            .fontColor(this.selectedID === item.id ?
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
                                            .select(this.selectedID === item.id)
                                            .onChange((isChecked: boolean) => {
                                                this.handleCheckboxChange(item.id, isChecked);
                                            })

                                    }
                                    .width(StyleConstants.TWENTY_PERCENT)
                                    .alignItems(HorizontalAlign.Center)
                                }
                                .height(StyleConstants.TEN_PERCENT)
                                .width(StyleConstants.FULL_PERCENT)
                                .borderStyle(BorderStyle.Solid)
                            }
                            .margin({
                                top: StyleConstants.FIVE_PERCENT,
                                left: StyleConstants.TWO_PERCENT,
                                right: StyleConstants.TWO_PERCENT,
                                bottom: StyleConstants.FIVE_PERCENT
                            })
                        }
                    })
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
        Navigation() {
            if(this.isLoading) this.LoadingContent();
            else this.MainContent();
        }
        .title($r('app.string.FormEdit_Title'))
        .titleMode(NavigationTitleMode.Mini)
        .hideBackButton(false)
        .height(StyleConstants.FULL_PERCENT)
        .width(StyleConstants.FULL_PERCENT)
        .onAppear(() => {
            Logger.debug(this.LOG_TAG, 'Loaded!');
        })
    }
}