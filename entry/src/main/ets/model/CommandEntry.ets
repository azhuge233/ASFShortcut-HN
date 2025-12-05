export default class CommandEntry {
    id: number = -1;
    nickname: string = "Command";
    command: string = "status";
    orderIndex: number = 0;
    accountInputRequired: number = 0;
    idInputRequired: number = 1;

    constructor(id: number, nickname: string, command: string, orderIndex: number, accountInputRequired: number, idInputRequired: number) {
        this.id = id;
        this.nickname = nickname;
        this.command = command;
        this.orderIndex = orderIndex;
        this.accountInputRequired = accountInputRequired;
        this.idInputRequired = idInputRequired;
    }
}