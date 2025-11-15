export default class CommandEntry {
    id: number = -1;
    nickname: string = "Command";
    command: string = "status";
    accountInputRequired: number = 0;
    idInputRequired: number = 1;

    constructor(id: number, nickname: string, command: string, accountInputRequired: number, idInputRequired: number) {
        this.id = id;
        this.nickname = nickname;
        this.command = command;
        this.accountInputRequired = accountInputRequired;
        this.idInputRequired = idInputRequired;
    }
}