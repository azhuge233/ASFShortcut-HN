import CommandEntry from '../model/CommandEntry'
import { CommandEntryJsonObject } from '../model/JsonObjects'

@ObservedV2
export class CommandEntryViewModel {
    @Trace id: number = -1;
    @Trace nickname: string = "";
    @Trace command: string = "";
    @Trace accountInputRequired: number = 0;
    @Trace idInputRequired: number = 0;

    updateCommand(commandEntry: CommandEntry) {
        this.id = commandEntry.id;
        this.nickname = commandEntry.nickname;
        this.command = commandEntry.command;
        this.accountInputRequired = commandEntry.accountInputRequired;
        this.idInputRequired = commandEntry.idInputRequired;
    }

    toCommandEntry(): CommandEntry {
        return new CommandEntry(
            this.id,
            this.nickname,
            this.command,
            this.accountInputRequired,
            this.idInputRequired
        );
    }

    toCommandEntryJsonObject(): CommandEntryJsonObject {
        return new CommandEntryJsonObject(
            this.nickname,
            this.command,
            this.accountInputRequired,
            this.idInputRequired
        );
    }

    get accountRequired(): boolean {
        return this.accountInputRequired === 1;
    }

    set accountRequired(value: boolean) {
        this.accountInputRequired = value ? 1 : 0;
    }

    get idRequired(): boolean {
        return this.idInputRequired === 1;
    }

    set idRequired(value: boolean) {
        this.idInputRequired = value ? 1 : 0;
    }
}