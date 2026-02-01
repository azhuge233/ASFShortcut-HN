export default class WidgetCommand {
    id: number;
    nickname: string;
    command: string;

    constructor(id: number, nickname: string, command: string) {
        this.id = id;
        this.nickname = nickname;
        this.command = command;
    }
}