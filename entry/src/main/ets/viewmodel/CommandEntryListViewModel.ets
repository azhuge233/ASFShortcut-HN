import Logger from '../common/utils/Logger';
import { PM } from '../common/utils/PM';
import CommandEntry from '../model/CommandEntry';
import CommandEntryList from '../model/CommandEntryList';
import { CommandEntryJsonObject } from '../model/JsonObjects';
import { CommandEntryViewModel } from "./CommandEntryViewModel";
import { formProvider } from '@kit.FormKit';
import CommonUtils from '../common/utils/CommonUtils';
import CommonConstants from '../common/constants/CommonConstants';

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

    async importData(address: string, password: string, entries: Array<CommandEntry>): Promise<boolean> {
        // 导入会清空全部绑定；先收集受影响 formID，成功后用空绑定重置卡片 UI
        const allSingleBindings = await this.pm.getAllCardBindingsSingle();
        const allMultipleBindings = await this.pm.getAllCardBindingsMultiple();

        const allFormIDMap: Map<string, string[]> = new Map<string, string[]>();
        allFormIDMap.set(CommonConstants.FORM_RESULT_MAP_KEY_SINGLE, allSingleBindings.map(binding => binding.formID));
        allFormIDMap.set(CommonConstants.FORM_RESULT_MAP_KEY_MULTIPLE, allMultipleBindings.map(binding => binding.formID));

        const success = await this.dataModel.importData(address, password, entries);
        if (success) {
            await this.loadCommandEntries();
            await this.updateForms(allFormIDMap);
        }
        return success;
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

    private async updateForms(formIDMap: Map<string, string[]>): Promise<boolean> {
        const singleFormIDs = formIDMap.get(CommonConstants.FORM_RESULT_MAP_KEY_SINGLE) ?? [];
        const multipleFormIDs = formIDMap.get(CommonConstants.FORM_RESULT_MAP_KEY_MULTIPLE) ?? [];

        if(singleFormIDs.length === 0 && multipleFormIDs.length === 0) return true;

        let allSuccess = true;

        for(const formID of singleFormIDs) {
            try {
                const formData = await this.pm.getFormDataByIDSingle(formID);

                // 如果 formData 不为空，生成新 FormBindingData 更新卡片 UI
                // 如果 formData 为空，说明该卡片已解绑，生成空 FormBindingData
                const formInfo = CommonUtils.createSingleCommandFormBindingData(formData ?? formID);
                await formProvider.updateForm(formID, formInfo);

                Logger.debug(this.LOG_TAG, `已更新单指令卡片, formID = ${formID}`);
            } catch (err) {
                allSuccess = false;
                Logger.error(this.LOG_TAG, `更新单指令卡片失败, formID = ${formID}, ${err}`);
            }
        }

        for(const formID of multipleFormIDs) {
            try {
                const formData = await this.pm.getFormDataByIDMultiple(formID);

                const formInfo = CommonUtils.createMultipleCommandFormBindingData(formData ?? formID);
                await formProvider.updateForm(formID, formInfo);

                Logger.debug(this.LOG_TAG, `已更新多指令卡片, formID = ${formID}`);
            } catch (err) {
                allSuccess = false;
                Logger.error(this.LOG_TAG, `更新多指令卡片失败, formID = ${formID}, ${err}`);
            }
        }

        return allSuccess;
    }
}