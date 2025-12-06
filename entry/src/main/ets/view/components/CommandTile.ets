import { CommandEntryViewModel } from '../../viewmodel/CommandEntryViewModel';
import Logger from '../../common/utils/Logger';
import StyleConstants from '../../common/constants/StyleConstants';
import CommonUtils from '../../common/utils/CommonUtils';
import CommonConstants from '../../common/constants/CommonConstants';

@ComponentV2
export struct CommandListItem {
    private LOG_TAG = "[view/components/CommandListItem]";

    @Param item: CommandEntryViewModel = new CommandEntryViewModel();

    // 回调函数
    @Param onAccountInput: () => Promise<string> = () => Promise.resolve("");
    @Param onIDInput: () => Promise<string> = () => Promise.resolve("");
    @Param onSendCommand: (command: string) => Promise<void> = async () => {};
    @Param onRunningStateChange: (processing: boolean) => void = () => {};

    @Local isRunning: boolean = false;

    // debug
    // 模拟长时间执行
    private async sleep(time: number) {
        await new Promise<void>(resolve => setTimeout(resolve, time));
    }

    // 设置条目运行状态
    // 设置本地运行状态参数，控制加载覆盖层的显示
    // 再向回调函数传出运行状态，供主页面控制本条目的启用/禁用
    private changeRunningState(isRunning: boolean) {
        this.isRunning = isRunning;
        this.onRunningStateChange(isRunning);
    }

    // 点击执行按钮后执行指令
    // 根据条目设置，弹出对应的输入页面
    private async runCommand() {
        try {
            this.changeRunningState(true);
            let command = this.item.command;

            if (this.item.accountInputRequired === 1 && this.onAccountInput) {
                let asfAcc = await this.onAccountInput();
                if(asfAcc === "") {
                    Logger.debug(this.LOG_TAG, `未输入ASF账户，取消执行`);
                    return;
                } else command = `${command} ${asfAcc}`;
            }

            if (this.item.idInputRequired === 1 && this.onIDInput) {
                let asfId = await this.onIDInput();
                if(asfId === "") {
                    Logger.debug(this.LOG_TAG, `未输入App/Sub/Def ID，取消执行`);
                    return;
                } else command = `${command} ${asfId}`;
            }

            await this.onSendCommand(command);
        } catch (err) {
            Logger.error(this.LOG_TAG, `<runCommand> error: ${err}`);
        } finally {
            this.changeRunningState(false);
        }
    }

    // 运行时的覆盖层
    @Builder
    RunningBlock() {
        Column()
            .height(StyleConstants.THIRTEEN_PERCENT)
            .width(StyleConstants.FULL_PERCENT)
            .backgroundColor($r("app.color.transparent"))
            .blur(StyleConstants.BLUE_LEVEL)
            .onClick(() => {})

        Column() {
            Progress({ value: 0, total: 100, type: ProgressType.Ring })
                .width(StyleConstants.COMMAND_TILE_PROGRESS_WIDTH)
                .style({
                    strokeWidth: StyleConstants.COMMAND_TILE_PROGRESS_STROKE_WIDTH,
                    status: ProgressStatus.LOADING,
                    shadow: true,
                    enableScanEffect: true,
                    enableSmoothEffect: true
                })
        }
        .width(StyleConstants.FULL_PERCENT)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {})
    }

    // 条目的主要内容
    @Builder
    MainContent() {
        Row() {
            Column({ space: StyleConstants.COMMAND_TILE_COL_SPACE }) {
                Column({ space: StyleConstants.COMMAND_TILE_COL_SPACE / 2 }) {
                    Text(this.item.nickname)
                        .fontSize(StyleConstants.COMMAND_TILE_NAME_FONT_SIZE)
                        .fontWeight(FontWeight.Medium)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width(StyleConstants.FULL_PERCENT)

                    Text(this.item.command)
                        .fontSize(StyleConstants.COMMAND_TILE_COMMAND_FONT_SIZE)
                        .maxLines(2)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width(StyleConstants.FULL_PERCENT)
                }
                .width(StyleConstants.FULL_PERCENT)

                Row({ space: StyleConstants.COMMAND_TILE_ROW_SPACE }) {
                    if (this.item.accountInputRequired === 1 || this.item.idInputRequired === 1) {
                        Text($r("app.string.CommandTile_Input_Required_Label"))
                            .fontSize(StyleConstants.COMMAND_TILE_LABEL_FONT_SIZE)
                            .margin({
                                right: StyleConstants.PADDING_TWO
                            })
                    }

                    if (this.item.accountInputRequired === 1) {
                        Text($r("app.string.CommandTile_Input_Required_ASF_Account_Label"))
                            .fontSize(StyleConstants.COMMAND_TILE_LABEL_FONT_SIZE)
                            .fontColor($r('app.color.tag_account_text'))
                            .backgroundColor($r('app.color.tag_account_bg'))
                            .padding({
                                left: StyleConstants.PADDING_EIGHT,
                                right: StyleConstants.PADDING_EIGHT,
                                top: StyleConstants.PADDING_TWO,
                                bottom: StyleConstants.PADDING_TWO
                            })
                            .borderRadius(10)
                    }

                    if (this.item.idInputRequired === 1) {
                        Text($r("app.string.CommandTile_Input_Required_ASF_ID_Label"))
                            .fontSize(StyleConstants.COMMAND_TILE_LABEL_FONT_SIZE)
                            .fontColor($r('app.color.tag_id_text'))
                            .backgroundColor($r('app.color.tag_id_bg'))
                            .padding({
                                left: StyleConstants.PADDING_EIGHT,
                                right: StyleConstants.PADDING_EIGHT,
                                top: StyleConstants.PADDING_TWO,
                                bottom: StyleConstants.PADDING_TWO
                            })
                            .borderRadius(10)
                    }

                    // 如果没有标签，添加一个占位空间保持高度一致
                    if (this.item.accountInputRequired === 0 && this.item.idInputRequired === 0) {
                        Text(' ')
                            .fontSize(StyleConstants.COMMAND_TILE_LABEL_FONT_SIZE)
                            .opacity(0)
                    }
                }
                .width(StyleConstants.FULL_PERCENT)
            }
            .width(StyleConstants.SEVENTY_FIVE_PERCENT)
            .padding({
                top: StyleConstants.PADDING_SIXTEEN,
                bottom: StyleConstants.PADDING_SIXTEEN,
                left: StyleConstants.PADDING_TWENTY,
                right: StyleConstants.PADDING_SIXTEEN
            })

            Column({ space: StyleConstants.COMMAND_TILE_COL_SPACE }) {
                Button(this.isRunning ? $r("app.string.CommandTile_Button_Label_Running") :
                    $r("app.string.CommandTile_Button_Label_Run"))
                    .enabled(!this.isRunning)
                    .stateEffect(true)
                    .onClick(() => {
                        CommonUtils.vibrate(CommonConstants.Vibrate_Effect_ID_HARD);
                        this.runCommand();
                    })
            }
            .width(StyleConstants.TWENTY_FIVE_PERCENT)
            .padding({
                right: StyleConstants.PADDING_TWO
            })
        }
    }

    build() {
        Stack({ alignContent: Alignment.Center }) {
            this.MainContent();

            if (this.isRunning) {
                this.RunningBlock();
            }
        }
        .width(StyleConstants.FULL_PERCENT)
    }
}