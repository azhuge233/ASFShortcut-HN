import CommandEntry from '../model/CommandEntry';
import CommandEntryList from '../model/CommandEntryList';
import { CommandEntryViewModel } from "./CommandEntryViewModel";

@ObservedV2
export default class CommandEntryListViewModel {
    @Trace commandEntries: Array<CommandEntryViewModel> = [];
    private dataModel: CommandEntryList = new CommandEntryList([]);

    async loadCommandEntries() {
        await this.dataModel.loadCommandEntries();

        this.commandEntries = this.dataModel.commandEntries.map(entry => {
            const viewModel = new CommandEntryViewModel();
            viewModel.updateCommand(entry);
            return viewModel;
        });
    }

    async addCommandEntry(commandEntry: CommandEntry): Promise<boolean> {
        const success = await this.dataModel.addCommandEntry(commandEntry);
        if (success) {
            await this.loadCommandEntries();
            return true;
        }
        return false;
    }

    async updateCommandEntry(commandEntry: CommandEntry): Promise<boolean> {
        const success = await this.dataModel.updateCommandEntry(commandEntry);
        if(success) {
            await this.loadCommandEntries();
            return true;
        }
        return false;
    }

    async deleteCommandEntry(commandEntry: CommandEntry): Promise<boolean> {
        const success = await this.dataModel.deleteCommandEntry(commandEntry);
        if(success) {
            await this.loadCommandEntries();
            return true;
        }
        return false;
    }

    async clearCommandEntry(): Promise<boolean> {
        const success = await this.dataModel.clearCommandEntry();
        if(success) {
            await this.loadCommandEntries();
            return true;
        }
        return false;
    }

    getNextId(): number {
        if (this.commandEntries.length === 0) return 1;
        const maxId = Math.max(...this.commandEntries.map(item => item.id));
        return maxId + 1;
    }
}