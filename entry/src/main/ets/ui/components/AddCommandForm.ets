import Logger from '../../common/utils/Logger';
import StyleConstants from '../../common/constants/StyleConstants';
import PageContext from '../common/PageContext';
import { CommandEditViewModel, EditSaveOutcome } from '../../viewmodel/CommandEditViewModel';
import { AppButton, AppButtonKind } from './AppButton';
import { AppInput } from './AppInput';

/**
 * 添加指令的表单体（设计 §2.5）：从 `AddCommand.ets` 搬出，控件与按钮样式不动。
 *
 * 唯一的视觉改动是内容顶距（设计 §2.6 ⑦）：首个 `Blank()` 与它的上下外边距删除，
 * 列的上内边距读 `FORM_PAGE_TOP_PADDING`，列占满视口并起始对齐——首节点顶边 = 标题栏底 + 24vp，
 * 与 `ASFSettingsPage` 同一条规则；列表三页首元素是卡片，仍是 16vp。
 *
 * 两个宿主共用它——`Index` 的第三个页签（常驻）与 `AddCommand` 的页面壳（桌面长按快捷方式直达）。
 * 草稿与保存逻辑都在传进来的 `CommandEditViewModel` 里，本组件不持状态：
 * 保存成功后依次「提示 → 清空草稿 → 抛 `onSaved`」，切不切页签由宿主决定。
 */
@ComponentV2
export struct AddCommandForm {
    private LOG_TAG = '[components/AddCommandForm]';

    @Require @Param viewModel: CommandEditViewModel;

    // 保存成功后的宿主动作：页签宿主切回指令列表，页面壳宿主什么都不做
    @Event onSaved: () => void = () => {};

    private uiContext = this.getUIContext();
    private promptAction = this.uiContext.getPromptAction();

    // 内容装得下就不让滑：视口高与内容高各在面积变化回调里回填，比较结果写进可观察字段（设计 §13.1 / §13.2.2）
    @Local scrollEnabled: boolean = true;
    private viewportHeight: number = 0;
    private contentHeight: number = 0;

    private updateScrollEnabled(): void {
        // 装得下时列高 = 视口高（列挂了 `minHeight`）：留 1vp 容差，布局取整的偏移不算超出
        this.scrollEnabled = this.contentHeight > this.viewportHeight + 1;
    }

    private async saveCommand(): Promise<void> {
        const outcome: EditSaveOutcome = await this.viewModel.save();

        if (outcome.ok) {
            PageContext.alert($r("app.string.AddCommand_Add_Success"), this.promptAction);
            this.viewModel.startAdd();
            this.onSaved();
            return;
        }

        if (outcome.failure === 'invalid') {
            PageContext.alert($r("app.string.AddCommand_Invalid_Input"), this.promptAction);
        } else if (outcome.failure === 'rejected') {
            PageContext.alert($r("app.string.AddCommand_Add_Failed_Try_Again"), this.promptAction);
        } else {
            Logger.error(this.LOG_TAG, `保存命令失败: ${outcome.failure}`);
            PageContext.alert($r("app.string.AddCommand_Add_Failed"), this.promptAction);
        }
    }

    build() {
        Scroll() {
            Column({ space: StyleConstants.ADD_COMMAND_COL_SPACE }) {
                // 内容顶距只有一处来源：列的上内边距（设计 §2.6 ⑦）。
                // 原来这里还首插一个 `Blank()` 带上下各 `MARGIN_TEN`，与列内边距、项间距叠成 40vp，
                // 首行比列表页低一截——三段留白只能留一段，已删
                // 名称输入
                Text($r("app.string.AddCommand_Name_Label"))
                    .fontSize(StyleConstants.ADD_COMMAND_LABEL_FONT_SIZE)
                    .alignSelf(ItemAlign.Start)
                    .margin({ left: StyleConstants.MARGIN_TWENTY })
                // 不设 `defaultFocus`：页签形态下切过来会自动拉起软键盘，遮住底栏与页签（设计 §2.5）
                AppInput({
                    placeholder: $r("app.string.AddCommand_Name_Input_Placeholder"),
                    text: this.viewModel.nickname,
                    onChange: (value: string) => {
                        this.viewModel.nickname = value;
                    }
                })
                    .margin({ left: StyleConstants.MARGIN_TWENTY, right: StyleConstants.MARGIN_TWENTY })

                // 命令输入
                Text($r("app.string.AddCommand_Command_Label"))
                    .fontSize(StyleConstants.ADD_COMMAND_LABEL_FONT_SIZE)
                    .alignSelf(ItemAlign.Start)
                    .margin({ left: StyleConstants.MARGIN_TWENTY, top: StyleConstants.MARGIN_TWENTY })
                // 盘上第二只输入框多一句 `defaultFocus(false)`，与平台默认值同义（不设即不调用，行为不变）
                AppInput({
                    placeholder: $r("app.string.AddCommand_Command_Input_Placeholder"),
                    text: this.viewModel.command,
                    onChange: (value: string) => {
                        this.viewModel.command = value;
                    }
                })
                    .margin({ left: StyleConstants.MARGIN_TWENTY, right: StyleConstants.MARGIN_TWENTY })

                // 选项区域 - 使用 Toggle 组件
                Column({ space: StyleConstants.ADD_COMMAND_OPTION_COL_SPACE }) {
                    Text($r("app.string.AddCommand_Options_Label"))
                        .fontSize(StyleConstants.ADD_COMMAND_LABEL_FONT_SIZE)
                        .alignSelf(ItemAlign.Start)
                        .margin({ bottom: StyleConstants.MARGIN_TEN })

                    // 需要输入账户的选项
                    Row({ space: StyleConstants.ADD_COMMAND_ROW_SPACE }) {
                        Toggle({ type: ToggleType.Checkbox, isOn: this.viewModel.accountRequired })
                            .onChange(
                                (value: boolean) => {
                                    this.viewModel.accountRequired = value;
                                }
                            )
                        Text($r("app.string.AddCommand_Needs_ASF_Account_Input_Label"))
                            .fontSize(StyleConstants.ADD_COMMAND_CHECK_LABEL_FONT_SIZE)
                    }
                    .justifyContent(FlexAlign.Start)
                    .width(StyleConstants.FULL_PERCENT)

                    // 需要输入 App ID 的选项
                    Row({ space: StyleConstants.ADD_COMMAND_ROW_SPACE }) {
                        Toggle({ type: ToggleType.Checkbox, isOn: this.viewModel.idRequired })
                            .onChange(
                                (value: boolean) => {
                                    this.viewModel.idRequired = value;
                                }
                            )
                        Text($r("app.string.AddCommand_Needs_ASF_ID_Input_Label"))
                            .fontSize(StyleConstants.ADD_COMMAND_CHECK_LABEL_FONT_SIZE)
                    }
                    .justifyContent(FlexAlign.Start)
                    .width(StyleConstants.FULL_PERCENT)
                }
                .alignSelf(ItemAlign.Start)
                .margin(
                    {
                        left: StyleConstants.MARGIN_TWENTY,
                        top: StyleConstants.MARGIN_TWENTY,
                        right: StyleConstants.MARGIN_TWENTY
                    }
                )
                .padding(StyleConstants.PADDING_FIFTEEN)
                .border({ width: StyleConstants.INPUT_BORDER_WIDTH, color: Color.Gray })
                .borderRadius(StyleConstants.INPUT_BORDER_RADIUS)

                // 按钮区域：次态（`Button(label)` 原样，不设 type / 字色）。
                // 宽度分两层：下面 `.width(SEVENTY_PERCENT)` 定外包层，`stretch` 不传（默认真）让内层填满它。
                // 传 `stretch: false` 内层会缩成内容宽并贴外包层左缘（实测 209 vs 791px，设计 §2.7 / K4）
                AppButton({
                    label: $r("app.string.AddCommand_Add_Button_Label"),
                    kind: AppButtonKind.Secondary,
                    isEnabled: this.viewModel.canSave() && !this.viewModel.isSaving,
                    onTap: () => {
                        this.saveCommand();
                    }
                })
                    .width(StyleConstants.SEVENTY_PERCENT)
                    .margin({ top: StyleConstants.MARGIN_FORTY })

                // 占位空间
                Blank()
            }
            // 列占满视口 + 起始对齐：内容不足一屏时列仍占满视口，居中「无论来自哪一层」都没有余量
            // （与设置四页同一套骨架，设计 §2.6 ①）。不设 `minHeight` 时列只有内容高，`Scroll` 会把整块表单居中，
            // 首行因此低 73.5vp——内容顶距只能由列的上内边距给（设计 §2.6 ⑦）
            .constraintSize({ minHeight: StyleConstants.FULL_PERCENT })
            .justifyContent(FlexAlign.Start)
            // 上内边距读 `FORM_PAGE_TOP_PADDING`：首内容节点顶边 = 标题栏底 + 24vp（设计 §2.6 ⑦）。
            // 表单页首元素是标签文字，16vp 贴着标题栏读作拥挤；列表三页首元素是卡片、自带内边距，仍读 `PAGE_PADDING`。
            // 左右与下仍是搬出前的 20vp——本批不重排输入与按钮样式（设计 §7 边界）
            .padding({
                top: StyleConstants.FORM_PAGE_TOP_PADDING,
                right: StyleConstants.PADDING_TWENTY,
                bottom: StyleConstants.PADDING_TWENTY,
                left: StyleConstants.PADDING_TWENTY
            })
            // 内容高 = 列实测高度：装得下时列被 `minHeight` 顶成视口高，不会超出
            .onAreaChange((_old: Area, now: Area) => {
                this.contentHeight = Number(now.height);
                this.updateScrollEnabled();
            })
        }
        // 搬进页签后容器换了宿主，显式占满：与搬出前在页面壳里「默认占满」的画面一致
        .width(StyleConstants.FULL_PERCENT)
        .height(StyleConstants.FULL_PERCENT)
        // 视口高 = 本 `Scroll` 实测高度；让出量（`contentEndOffset`）属于滚动范围，不进本判定（设计 §13.2.2）
        .onAreaChange((_old: Area, now: Area) => {
            this.viewportHeight = Number(now.height);
            this.updateScrollEnabled();
        })
        .enableScrollInteraction(this.scrollEnabled)
        .contentEndOffset(StyleConstants.PAGE_PADDING + StyleConstants.INDEX_TAB_BAR_HEIGHT)
    }
}
