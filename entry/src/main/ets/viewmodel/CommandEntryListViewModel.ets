import Logger from '../common/utils/Logger';
import { FormBindingStore } from '../data/store/FormBindingStore';
import { FormPublisher } from '../data/form/FormPublisher';
import CommandEntry from '../domain/model/CommandEntry';
import CommandEntryList from '../domain/model/CommandEntryList';
import { CommandEntryJsonObject, ExportJsonObject } from '../domain/model/JsonObjects';
import { CommandImportResult } from '../domain/service/CommandImportService';
import { CommandMutationResult } from '../domain/service/CommandService';
import { CommandEntryViewModel } from "./CommandEntryViewModel";
import { formProvider } from '@kit.FormKit';
import CommonConstants from '../common/constants/CommonConstants';

@ObservedV2
export default class CommandEntryListViewModel {
    private LOG_TAG = '[CommandEntryListViewModel]';

    @Trace commandEntries: Array<CommandEntryViewModel> = [];
    private dataModel: CommandEntryList = new CommandEntryList([]);

    private pm = FormBindingStore.getInstance();
    private publisher = FormPublisher.getInstance();

    async loadCommandEntries() {
        const loaded = await this.dataModel.loadCommandEntries();

        // 读失败时保留上一次的列表：把失败显示成「没有指令」是假话（错误态与重试入口在 B3 的 VM 上）
        if (!loaded) return;

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

    async updateCommandEntry(commandEntry: CommandEntry): Promise<CommandMutationResult> {
        const result = await this.dataModel.updateCommandEntry(commandEntry);
        // 更新成功，affected 携带绑定了该 entry 的所有 formID
        if (result.ok) {
            await this.loadCommandEntries();
            await this.updateForms(result.affected);
        }
        return result;
    }

    async deleteCommandEntry(commandEntry: CommandEntry): Promise<CommandMutationResult> {
        const result = await this.dataModel.deleteCommandEntry(commandEntry);
        if (result.ok) {
            // 删除后刷新 commandEntries 和 dataModel 内的 commandEntries
            await this.loadCommandEntries();
            // 刷新后再更新列表内剩余条目的位置下标
            // 要注意执行顺序，如果在刷新前执行，位置下标不变
            // 因为 commandEntries 和 dataModel 内的 commandEntries 未更新
            await this.updateEntriesOrder();
            await this.updateForms(result.affected);
        }
        return result;
    }

    async clearCommandEntry(): Promise<CommandMutationResult> {
        const result = await this.dataModel.clearCommandEntry();
        if (result.ok) {
            await this.loadCommandEntries();
            await this.updateForms(result.affected);
        }
        return result;
    }

    async importData(json: ExportJsonObject): Promise<CommandImportResult> {
        // 导入会清空全部绑定；先收集受影响 formID，成功后用空绑定重置卡片 UI
        const allSingleBindings = await this.pm.listSingle();
        const allMultipleBindings = await this.pm.listMultiple();

        const allFormIDMap: Map<string, string[]> = new Map<string, string[]>();
        allFormIDMap.set(CommonConstants.FORM_RESULT_MAP_KEY_SINGLE, allSingleBindings.map(pair => pair[0]));
        allFormIDMap.set(CommonConstants.FORM_RESULT_MAP_KEY_MULTIPLE, allMultipleBindings.map(pair => pair[0]));

        const result = await this.dataModel.importData(json);
        if (result.ok) {
            await this.loadCommandEntries();
            await this.updateForms(allFormIDMap);
        }
        return result;
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

        // 重新分配连续的 orderIndex，交仓库整批写入
        const reorderedEntries = currentEntries.map((entry, index) => {
            entry.orderIndex = index;
            return entry.toCommandEntry();
        });

        const success = await this.dataModel.updateEntriesOrder(reorderedEntries);

        if (success) {
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
        const reorderedEntries = this.commandEntries.map((entry, index) => {
            entry.orderIndex = index;
            return entry.toCommandEntry();
        });

        const success = await this.dataModel.updateEntriesOrder(reorderedEntries);

        if (success) {
            await this.loadCommandEntries();
            return true;
        }
        return false;
    }

    private async updateForms(formIDMap: Map<string, string[]>): Promise<boolean> {
        const singleFormIDs = formIDMap.get(CommonConstants.FORM_RESULT_MAP_KEY_SINGLE) ?? [];
        const multipleFormIDs = formIDMap.get(CommonConstants.FORM_RESULT_MAP_KEY_MULTIPLE) ?? [];

        if (singleFormIDs.length === 0 && multipleFormIDs.length === 0) return true;

        let allSuccess = true;

        for (const formID of singleFormIDs) {
            try {
                const formData = await this.pm.getSingle(formID);

                // 如果 formData 不为空，生成新 FormBindingData 更新卡片 UI
                // 如果 formData 为空，说明该卡片已解绑，生成空 FormBindingData
                const formInfo = this.publisher.createSingleCommandFormBindingData(formData ?? formID);
                // 本路径 1.7.1 不重试，B2 保持直调（加重试是第七项行为变更，B3 统一口径）
                await formProvider.updateForm(formID, formInfo);

                Logger.debug(this.LOG_TAG, `已更新单指令卡片, formID = ${formID}`);
            } catch (err) {
                allSuccess = false;
                Logger.error(this.LOG_TAG, `更新单指令卡片失败, formID = ${formID}, ${err}`);
            }
        }

        for (const formID of multipleFormIDs) {
            try {
                const formData = await this.pm.getMultiple(formID);

                const formInfo = this.publisher.createMultipleCommandFormBindingData(formData ?? formID);
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
