import Logger from '../common/utils/Logger';
import CommandEntry from '../domain/model/CommandEntry';
import CommandListViewModel from './CommandListViewModel';
import { CommandEntryViewModel } from './CommandEntryViewModel';

/** 保存失败类别（设计 §2.4.2）：`invalid` = 校验不过，`rejected` = 仓库返回失败，`error` = 抛错 */
export type EditFailureKind = 'none' | 'invalid' | 'rejected' | 'error';

/**
 * 保存结果：失败类别够页面选文案（设计 §2.4.2）。
 */
export class EditSaveOutcome {
    ok: boolean = false;
    failure: EditFailureKind = 'none';

    static succeed(): EditSaveOutcome {
        const outcome = new EditSaveOutcome();
        outcome.ok = true;
        return outcome;
    }

    static fail(failure: EditFailureKind): EditSaveOutcome {
        const outcome = new EditSaveOutcome();
        outcome.failure = failure;
        return outcome;
    }
}

/**
 * 新建 / 编辑一条指令的一屏 VM（设计 §2.4.2），`AddCommand` 与 `EditPage` 共用。
 *
 * 动作落到 `CommandListViewModel`：新增走 `addEntry`、编辑走 `updateEntry`——
 * 卡片刷新与列表重载都在那条路上，本类不碰仓库。
 */
@ObservedV2
export class CommandEditViewModel {
    private LOG_TAG = '[CommandEditViewModel]';

    @Trace nickname: string = '';
    @Trace command: string = '';
    @Trace accountRequired: boolean = false;
    @Trace idRequired: boolean = false;
    @Trace isSaving: boolean = false;

    // 保存成功回调：页面负责关页 / 清空草稿
    onSaved: (() => void) | null = null;

    private editMode: boolean = false;
    // 编辑态要原样带回的两个字段：`CommandEntry` 的 id 与排序下标不在草稿里显示
    private id: number = -1;
    private orderIndex: number = 0;

    private list: CommandListViewModel;

    constructor(list: CommandListViewModel) {
        this.list = list;
    }

    // 新建为 false，编辑为 true
    get isEditMode(): boolean {
        return this.editMode;
    }

    /** 清空草稿，进入新建态 */
    startAdd(): void {
        this.editMode = false;
        this.id = -1;
        this.orderIndex = 0;
        this.nickname = '';
        this.command = '';
        this.accountRequired = false;
        this.idRequired = false;
    }

    /** 用来源条目填草稿，进入编辑态 */
    startEdit(source: CommandEntryViewModel): void {
        this.editMode = true;
        this.id = source.id;
        this.orderIndex = source.orderIndex;
        this.nickname = source.nickname;
        this.command = source.command;
        this.accountRequired = source.accountRequired;
        this.idRequired = source.idRequired;
    }

    /** 两字段 `trim()` 均非空 */
    canSave(): boolean {
        return this.nickname.trim() !== '' && this.command.trim() !== '';
    }

    async save(): Promise<EditSaveOutcome> {
        if (!this.canSave()) return EditSaveOutcome.fail('invalid');

        this.isSaving = true;

        try {
            const entry: CommandEntry = new CommandEntry(this.id, this.nickname, this.command, this.orderIndex,
                this.accountRequired ? 1 : 0, this.idRequired ? 1 : 0);

            let saved: boolean = false;
            if (this.editMode) {
                const result = await this.list.updateEntry(entry);
                saved = result.ok;
                if (!saved) {
                    // 更新失败的原因留在领域结果里：界面按类别提示，日志留细节
                    Logger.warn(this.LOG_TAG, `save() 更新失败, ${result.reason}`);
                }
            } else {
                saved = await this.list.addEntry(entry);
            }

            if (!saved) return EditSaveOutcome.fail('rejected');

            if (this.onSaved) this.onSaved();
            return EditSaveOutcome.succeed();
        } catch (err) {
            Logger.error(this.LOG_TAG, `save() 失败, ${err}`);
            return EditSaveOutcome.fail('error');
        } finally {
            this.isSaving = false;
        }
    }
}
