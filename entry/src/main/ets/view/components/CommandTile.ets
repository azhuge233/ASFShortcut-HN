import { CommandEntryViewModel } from '../../viewmodel/CommandEntryViewModel';
import Logger from '../../common/utils/Logger';

@ComponentV2
export struct CommandListItem {
    private LOG_TAG = "[view/components/CommandListItem]";

    @Param item: CommandEntryViewModel = new CommandEntryViewModel();

    // 回调函数
    @Param onAccountInput: () => Promise<string> = () => Promise.resolve("");
    @Param onIDInput: () => Promise<string> = () => Promise.resolve("");
    @Param onSendCommand: (command: string) => Promise<void> = async () => {};
    @Param onProcessingChange: (processing: boolean) => void = () => {};

    async runCommand() {
        try {
            let command = this.item.command;

            if (this.item.accountInputRequired === 1 && this.onAccountInput) {
                command = `${command} ${await this.onAccountInput()}`;
            }

            if (this.item.idInputRequired === 1 && this.onIDInput) {
                command = `${command} ${await this.onIDInput()}`;
            }

            this.onProcessingChange(true);
            await this.onSendCommand(command);
        } catch (err) {
            Logger.error(this.LOG_TAG, `<runCommand> error: ${err}`);
        } finally {
            this.onProcessingChange(false);
        }
    }

    build() {
        Row() {
            Column({ space: 12 }) {
                Column({ space: 6 }) {
                    Text(this.item.nickname)
                        .fontSize(16)
                        .fontWeight(FontWeight.Medium)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width('100%')

                    Text(this.item.command)
                        .fontSize(13)
                        .maxLines(2)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .width('100%')
                }
                .width('100%')

                Row({ space: 8 }) {
                    if (this.item.accountInputRequired === 1 || this.item.idInputRequired === 1) {
                        Text($r("app.string.CommandTile_Input_Required_Label"))
                            .fontSize(11)
                            .margin({
                                right: 2
                            })
                    }

                    if (this.item.accountInputRequired === 1) {
                        Text($r("app.string.CommandTile_Input_Required_ASF_Account_Label"))
                            .fontSize(11)
                            .fontColor($r('app.color.tag_account_text'))
                            .backgroundColor($r('app.color.tag_account_bg'))
                            .padding({
                                left: 8,
                                right: 8,
                                top: 2,
                                bottom: 2
                            })
                            .borderRadius(10)
                    }

                    if (this.item.idInputRequired === 1) {
                        Text($r("app.string.CommandTile_Input_Required_ASF_ID_Label"))
                            .fontSize(11)
                            .fontColor($r('app.color.tag_id_text'))
                            .backgroundColor($r('app.color.tag_id_bg'))
                            .padding({
                                left: 8,
                                right: 8,
                                top: 2,
                                bottom: 2
                            })
                            .borderRadius(10)
                    }

                    // 如果没有标签，添加一个占位空间保持高度一致
                    if (this.item.accountInputRequired === 0 && this.item.idInputRequired === 0) {
                        Text(' ')
                            .fontSize(11)
                            .opacity(0)
                    }
                }
                .width('100%')
            }
            .width('75%')
            .padding({
                top: 16,
                bottom: 16,
                left: 20,
                right: 16
            })

            Column({ space: 12 }) {
                Button('Run')
                    .onClick(() => {
                        this.runCommand();
                    })
            }
            .width('25%')
            .padding({
                right: 5
            })
        }
        .width('100%')
    }
}