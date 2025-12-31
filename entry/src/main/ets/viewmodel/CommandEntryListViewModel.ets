import Logger from '../common/utils/Logger';
import { PM } from '../common/utils/PM';
import CommandEntry from '../model/CommandEntry';
import CommandEntryList from '../model/CommandEntryList';
import { CommandEntryJsonObject } from '../model/JsonObjects';
import { CommandEntryViewModel } from "./CommandEntryViewModel";
import { formProvider } from '@kit.FormKit';
import CommonUtils from '../common/utils/CommonUtils';

@ObservedV2
export default class CommandEntryListViewModel {
    private LOG_TAG = '[CommandEntryListViewModel]';

    @Trace commandEntries: Array<CommandEntryViewModel> = [];
    private dataModel: CommandEntryList = new CommandEntryList([]);

    private pm = PM.getInstance();

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
        const result = await this.dataModel.updateCommandEntry(commandEntry);
        // 更新成功，返回绑定了该 entry 的所有 formID
        // 更新失败，返回 false
        if(typeof(result) !== "boolean") {
            await this.loadCommandEntries();
            await this.updateForms(result);
            return true;
        }
        return false;
    }

    async deleteCommandEntry(commandEntry: CommandEntry): Promise<boolean> {
        const result = await this.dataModel.deleteCommandEntry(commandEntry);
        // 删除成功，返回绑定了该 entry 的所有 formID
        // 删除失败，返回 false
        if(typeof(result) !== "boolean") {
            // 删除后刷新 commandEntries 和 dataModel 内的 commandEntries
            await this.loadCommandEntries();
            // 刷新后再更新列表内剩余条目的位置下标
            // 要注意执行顺序，如果在刷新前执行，位置下标不变
            // 因为 commandEntries 和 dataModel 内的 commandEntries 未更新
            await this.updateEntriesOrder();
            await this.updateForms(result);
            return true;
        }
        return false;
    }

    async clearCommandEntry(): Promise<boolean> {
        const result = await this.dataModel.clearCommandEntry();
        if(typeof(result) !== "boolean") {
            await this.loadCommandEntries();
            await this.updateForms(result);
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

    private async updateForms(formIDs: string[]): Promise<boolean> {
        if(formIDs.length === 0) return true;

        try {
            formIDs.forEach(async formID => {
                const formData = await this.pm.getFormDataByID(formID);

                // 如果 formData 不为空，生成新 FormBindingData 更新卡片 UI
                // 如果 formData 为空，说明该卡片已解绑，生成空 FormBindingData
                const formInfo = CommonUtils.createFormBindingData(formData ?? formID);
                await formProvider.updateForm(formID, formInfo);

                Logger.debug(this.LOG_TAG, `已更新卡片, formID = ${formID}`);
            });

            return true;
        } catch (err) {
            Logger.error(this.LOG_TAG, `updateForms() 错误, ${err}`);
            return false;
        }
    }
}