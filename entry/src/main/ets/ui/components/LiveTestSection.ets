import StyleConstants from '../../common/constants/StyleConstants';
import CommandListViewModel from '../../viewmodel/CommandListViewModel';

/**
 * ASF 测试 tab 的内容区（B3 从 `Index.ets` 拆出，设计 §3.0 的拆分计划）。
 *
 * 只管呈现与输入：三个输入直接写 `CommandListViewModel` 的可观察字段，
 * 发送动作经 `onSend` 抛回页面（振动、结果对话框与页面栈都留在页面）。
 */
@ComponentV2
export struct LiveTestSection {
    @Require @Param viewModel: CommandListViewModel;

    @Event onSend: () => Promise<void> = async () => {
    };

    build() {
        Scroll() {
            Column() {
                // 提示信息
                Column() {
                    Text($r("app.string.LiveTest_Notice_Title"))
                        .fontSize(StyleConstants.LIVE_TEST_LABEL_FONT_SIZE)
                        .fontWeight(FontWeight.Bold)
                        .fontColor($r("sys.color.font_emphasize"))
                        .margin({ bottom: StyleConstants.MARGIN_FIVE })

                    Text($r("app.string.LiveTest_Notice_Content"))
                        .fontSize(StyleConstants.LIVE_TEST_LABEL_FONT_SIZE - 2)
                        .fontColor(Color.Gray)
                        .textAlign(TextAlign.Start)
                }
                .width(StyleConstants.NINETY_PERCENT)
                .padding(StyleConstants.PADDING_TEN)
                .backgroundColor($r("app.color.index_test_page_notice_background"))
                .borderRadius(StyleConstants.INPUT_BORDER_RADIUS)
                .margin({ bottom: StyleConstants.MARGIN_TEN })

                // 服务器地址输入
                Text($r("app.string.LiveTest_Address_Label"))
                    .fontSize(StyleConstants.LIVE_TEST_LABEL_FONT_SIZE)
                    .alignSelf(ItemAlign.Start)
                    .margin({
                        bottom: StyleConstants.MARGIN_TEN
                    })

                Row() {
                    TextInput({
                        text: this.viewModel.testAddress,
                        placeholder: $r("app.string.LiveTest_Address_Input_Placeholder")
                    })
                        .layoutWeight(1)
                        .border({
                            width: StyleConstants.INPUT_BORDER_WIDTH,
                            color: Color.Gray
                        })
                        .padding(StyleConstants.PADDING_TEN)
                        .onChange((value: string) => {
                            this.viewModel.testAddress = value;
                        })

                    Text("/Api/Command")
                        .fontSize(StyleConstants.LIVE_TEST_LABEL_FONT_SIZE - 2)
                        .margin({ left: StyleConstants.MARGIN_TEN })
                }
                .width(StyleConstants.NINETY_PERCENT)
                .margin({ bottom: StyleConstants.MARGIN_TEN })

                // 密码输入
                Text($r("app.string.LiveTest_Password_Label"))
                    .fontSize(StyleConstants.LIVE_TEST_LABEL_FONT_SIZE)
                    .alignSelf(ItemAlign.Start)
                    .margin({
                        bottom: StyleConstants.MARGIN_TEN
                    })

                TextInput({
                    text: this.viewModel.testPassword,
                    placeholder: $r("app.string.LiveTest_Password_Input_Placeholder")
                })
                    .type(InputType.Password)
                    .width(StyleConstants.NINETY_PERCENT)
                    .border({
                        width: StyleConstants.INPUT_BORDER_WIDTH,
                        color: Color.Gray
                    })
                    .padding(StyleConstants.PADDING_TEN)
                    .onChange((value: string) => {
                        this.viewModel.testPassword = value;
                    })
                    .margin({ bottom: StyleConstants.MARGIN_TEN })

                // 指令输入
                Text($r("app.string.LiveTest_Command_Label"))
                    .fontSize(StyleConstants.LIVE_TEST_LABEL_FONT_SIZE)
                    .alignSelf(ItemAlign.Start)
                    .margin({
                        bottom: StyleConstants.MARGIN_TEN
                    })

                TextInput({
                    text: this.viewModel.testCommand,
                    placeholder: $r("app.string.LiveTest_Command_Input_Placeholder")
                })
                    .width(StyleConstants.NINETY_PERCENT)
                    .border({
                        width: StyleConstants.INPUT_BORDER_WIDTH,
                        color: Color.Gray
                    })
                    .padding(StyleConstants.PADDING_TEN)
                    .onChange((value: string) => {
                        this.viewModel.testCommand = value;
                    })
                    .margin({ bottom: StyleConstants.MARGIN_FORTY })

                // 发送按钮
                Button($r("app.string.LiveTest_Send_Button_Label"), { type: ButtonType.Capsule })
                    .width(StyleConstants.EIGHTY_PERCENT)
                    .fontColor(Color.White)
                    .enabled(!this.viewModel.isProcessing &&
                        this.viewModel.testAddress.trim() !== '' &&
                        this.viewModel.testPassword.trim() !== '' &&
                        this.viewModel.testCommand.trim() !== '')
                    .onClick(async () => {
                        await this.onSend();
                    })
                    .margin({ bottom: StyleConstants.MARGIN_TWENTY })

                Blank()
                    .layoutWeight(1)
            }
        }
    }
}
