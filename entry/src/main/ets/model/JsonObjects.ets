export class ExportJson {
    Settings: SettingsJsonObject = new SettingsJsonObject("", "");
    CommandEntryList: Array<CommandEntryJsonObject> = [];

    constructor(settings: SettingsJsonObject, commandEntryList: Array<CommandEntryJsonObject>) {
        this.Settings = settings;
        this.CommandEntryList = commandEntryList;
    }
}

export class SettingsJsonObject {
    Address: string = "";
    Password: string = "";

    constructor(address: string, password: string) {
        this.Address = address;
        this.Password = password;
    }
}

export class CommandEntryJsonObject {
    Nickname: string = "";
    Command: string = "";
    AIR: number = 0;
    IIR: number = 0;

    constructor(nickname: string, command: string, air: number, iir: number) {
        this.Nickname = nickname;
        this.Command = command;
        this.AIR = air;
        this.IIR = iir;
    }
}