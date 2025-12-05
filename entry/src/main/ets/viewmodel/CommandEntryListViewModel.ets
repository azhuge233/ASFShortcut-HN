import CommandEntry from '../model/CommandEntry';
import CommandEntryList from '../model/CommandEntryList';
import { CommandEntryJsonObject } from '../model/JsonObjects';
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
            // 删除后刷新 commandEntries 和 dataModel 内的 commandEntries
            await this.loadCommandEntries();
            // 刷新后再更新列表内剩余条目的位置下标
            // 要注意执行顺序，如果在刷新前执行，位置下标不变
            // 因为 commandEntries 和 dataModel 内的 commandEntries 未更新
            await this.updateEntriesOrder();
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

    async toCommandEntryJsonObjectList(): Promise<Array<CommandEntryJsonObject>> {
        await this.loadCommandEntries();
        return this.commandEntries.map(entry => entry.toCommandEntryJsonObject());
    }

    async reorderEntries(fromIndex: number, toIndex: number): Promise<boolean> {
        if (fromIndex === toIndex || fromIndex < 0 || toIndex < 0 ||
            fromIndex >= this.commandEntries.length || toIndex >= this.commandEntries.length) {
            return false;
        }

        // 创建当前视图模型数组的副本
        const currentEntries = [...this.commandEntries];

        const movedItem = currentEntries.splice(fromIndex, 1);
        currentEntries.splice(toIndex, 0, movedItem[0]);

        // 重新分配连续的 orderIndex
        const reorderedEntriesWithNewIndex = currentEntries.map((entry, index) => {
            entry.orderIndex = index;
            return entry;
        });

        // 批量更新数据库的数据
        const updatePayload = reorderedEntriesWithNewIndex.map((entry, index) => [entry.id, index]);
        const success = await this.dataModel.updateEntriesOrder(updatePayload);

        if(success) {
            await this.loadCommandEntries();
            return true;
        }
        return false;
    }

    // 私有方法
    // 删除条目后，重新计算每个指令条目的位置
    // 并同步到数据库
    private async updateEntriesOrder(): Promise<boolean> {
        // 重新设置当前列表条目的位置下标，生成新的列表
        const reorderedEntriesWithNewIndex = this.commandEntries.map((entry, index) => {
            entry.orderIndex = index;
            return entry;
        });

        // 提取新列表的 [id - 位置] 下标映射（长度为2的数组）
        const updatePayload = reorderedEntriesWithNewIndex.map((entry, index) => [entry.id, index]);
        // 更新到数据库
        const success = await this.dataModel.updateEntriesOrder(updatePayload);

        if(success) {
            await this.loadCommandEntries();
            return true;
        }
        return false;
    }
}