import StyleConstants from '../../common/constants/StyleConstants';
import CommandListViewModel from '../../viewmodel/CommandListViewModel';
import { AppButton, AppButtonKind } from './AppButton';
import { AppInput } from './AppInput';

/**
 * ASF 测试 tab 的内容区（B3 从 `Index.ets` 拆出，设计 §3.0 的拆分计划）。
 *
 * 只管呈现与输入：三个输入直接写 `CommandListViewModel` 的可观察字段，
 * 发送动作经 `onSend` 抛回页面（振动、结果对话框与页面栈都留在页面）。
 *
 * 三处裸 `TextInput` 与发送键都是组件：版式补在列上（本页不经 `AppPage`，没有页面级内边距），
 * 输入框净宽与另两页同一条算式——屏宽 − 20（列）× 2 − 20（外边距）× 2 = 屏宽 − 80（设计 §2.5 / §2.6）。
 *
 * 纵向节奏只有两个来源：组间距 = 组尾元素的下外边距 `MARGIN_FORTY`（提示卡 / 地址行 / 密码框），
 * 组内间距 = 标签的下外边距 `MARGIN_TEN`；末组到发送键也是 `MARGIN_FORTY`，两者互不叠加（设计 §12.3）。
 *
 * `Scroll` 挂 `contentEndOffset` 让出悬浮底栏那一条底带，表达式与主列表逐字同形（设计 §12.1 / §12.3）。
 */
@ComponentV2
export struct LiveTestSection {
    @Require @Param viewModel: CommandListViewModel;

    @Event onSend: () => Promise<void> = async () => {
    };

    // 内容装得下就不让滑：视口高与内容高各在面积变化回调里回填，比较结果写进可观察字段（设计 §13.1 / §13.2.2）
    @Local scrollEnabled: boolean = true;
    private viewportHeight: number = 0;
    private contentHeight: number = 0;

    private updateScrollEnabled(): void {
        // 本页的列没有 `minHeight`：装得下时列高即内容高、小于视口高。留 1vp 容差抵布局取整
        this.scrollEnabled = this.contentHeight > this.viewportHeight + 1;
    }

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

                    // 撑宽机制：卡自己不设 `.width()`，由这一句把卡顶到可用槽宽（标题不设 width，保居中）
                    Text($r("app.string.LiveTest_Notice_Content"))
                        .fontSize(StyleConstants.LIVE_TEST_LABEL_FONT_SIZE - 2)
                        .fontColor(Color.Gray)
                        .textAlign(TextAlign.Start)
                        .width(StyleConstants.FULL_PERCENT)
                }
                // 不设 `.width()`：卡宽由卡内正文那一句 `100%` 顶到槽宽——与下方地址行同一条实测，
                // 自己写 `100%` 再叠左右外边距只会溢出、边缘仍停在列内边距上。左右各挂 `MARGIN_TWENTY`
                // 后卡净宽 = 屏宽 − 80，左右边缘与同页标签、输入框同缘（设计 §11.2 / §11.7）
                .padding(StyleConstants.PADDING_TEN)
                .backgroundColor($r("app.color.index_test_page_notice_background"))
                .borderRadius(StyleConstants.INPUT_BORDER_RADIUS)
                .margin({
                    left: StyleConstants.MARGIN_TWENTY,
                    right: StyleConstants.MARGIN_TWENTY,
                    bottom: StyleConstants.MARGIN_FORTY
                })

                // 服务器地址输入
                Text($r("app.string.LiveTest_Address_Label"))
                    .fontSize(StyleConstants.LIVE_TEST_LABEL_FONT_SIZE)
                    .alignSelf(ItemAlign.Start)
                    .margin({
                        left: StyleConstants.MARGIN_TWENTY,
                        bottom: StyleConstants.MARGIN_TEN
                    })

                // 地址行 = 输入框 + 后缀，两者合计宽 = 屏宽 − 80；后缀宽度由文字自身给（设计 §2.6）
                Row() {
                    AppInput({
                        text: this.viewModel.testAddress,
                        placeholder: $r("app.string.LiveTest_Address_Input_Placeholder"),
                        onChange: (value: string) => {
                            this.viewModel.testAddress = value;
                        }
                    })
                        .layoutWeight(1)

                    Text("/Api/Command")
                        .fontSize(StyleConstants.LIVE_TEST_LABEL_FONT_SIZE - 2)
                        .margin({ left: StyleConstants.MARGIN_TEN })
                }
                // 不设 `.width()`：100% 已吃满列内容宽，再叠左右外边距只会溢出——外边距收缩不了盒子，
                // 行左缘会停在列的内边距边缘（实测 65px，同页另两处 130px）。行自身收缩到列内容宽减外边距后，
                // 左缘才落在 40vp（设计 §2.6）
                .margin({
                    left: StyleConstants.MARGIN_TWENTY,
                    right: StyleConstants.MARGIN_TWENTY,
                    bottom: StyleConstants.MARGIN_FORTY
                })

                // 密码输入
                Text($r("app.string.LiveTest_Password_Label"))
                    .fontSize(StyleConstants.LIVE_TEST_LABEL_FONT_SIZE)
                    .alignSelf(ItemAlign.Start)
                    .margin({
                        left: StyleConstants.MARGIN_TWENTY,
                        bottom: StyleConstants.MARGIN_TEN
                    })

                // `password: true` 承接密码眼睛：原生输入框在 `InputType.Password` 下自带显隐图标
                AppInput({
                    text: this.viewModel.testPassword,
                    placeholder: $r("app.string.LiveTest_Password_Input_Placeholder"),
                    password: true,
                    onChange: (value: string) => {
                        this.viewModel.testPassword = value;
                    }
                })
                    .margin({
                        left: StyleConstants.MARGIN_TWENTY,
                        right: StyleConstants.MARGIN_TWENTY,
                        bottom: StyleConstants.MARGIN_FORTY
                    })

                // 指令输入
                Text($r("app.string.LiveTest_Command_Label"))
                    .fontSize(StyleConstants.LIVE_TEST_LABEL_FONT_SIZE)
                    .alignSelf(ItemAlign.Start)
                    .margin({
                        left: StyleConstants.MARGIN_TWENTY,
                        bottom: StyleConstants.MARGIN_TEN
                    })

                AppInput({
                    text: this.viewModel.testCommand,
                    placeholder: $r("app.string.LiveTest_Command_Input_Placeholder"),
                    onChange: (value: string) => {
                        this.viewModel.testCommand = value;
                    }
                })
                    .margin({
                        left: StyleConstants.MARGIN_TWENTY,
                        right: StyleConstants.MARGIN_TWENTY,
                        bottom: StyleConstants.MARGIN_FORTY
                    })

                // 发送按钮：主态（胶囊 + 白字）不变，宽度从 80% 收到与另两页同一条 70%（设计 §3 第 16 行）。
                // `stretch` 不传（默认真）：内层 `Button` 填满调用点给的 70%，三页按钮才等宽（设计 §2.7 / K4）
                AppButton({
                    label: $r("app.string.LiveTest_Send_Button_Label"),
                    kind: AppButtonKind.Primary,
                    isEnabled: !this.viewModel.isProcessing &&
                        this.viewModel.testAddress.trim() !== '' &&
                        this.viewModel.testPassword.trim() !== '' &&
                        this.viewModel.testCommand.trim() !== '',
                    onTap: async () => {
                        await this.onSend();
                    }
                })
                    .width(StyleConstants.SEVENTY_PERCENT)
                    .margin({ bottom: StyleConstants.MARGIN_TWENTY })

                Blank()
                    .layoutWeight(1)
            }
            // 本页不经 `AppPage`，页面级内边距不存在，所以补在列上（设计 §2.6）
            .padding({
                left: StyleConstants.PADDING_TWENTY,
                right: StyleConstants.PADDING_TWENTY
            })
            // 内容高 = 列实测高度：本列的列高由内容撑开，装得下时必然小于视口高
            .onAreaChange((_old: Area, now: Area) => {
                this.contentHeight = Number(now.height);
                this.updateScrollEnabled();
            })
        }
        // 视口高 = 本 `Scroll` 实测高度；让出量（`contentEndOffset`）属于滚动范围，不进本判定（设计 §13.2.2）
        .onAreaChange((_old: Area, now: Area) => {
            this.viewportHeight = Number(now.height);
            this.updateScrollEnabled();
        })
        .enableScrollInteraction(this.scrollEnabled)
        .contentEndOffset(StyleConstants.PAGE_PADDING + StyleConstants.INDEX_TAB_BAR_HEIGHT)
    }
}
