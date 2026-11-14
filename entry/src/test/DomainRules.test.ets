import { describe, it, expect } from '@ohos/hypium';

import CommandEntry from '../main/ets/domain/model/CommandEntry';
import CommandEntryList from '../main/ets/domain/model/CommandEntryList';
import MultipleCommandsFormData from '../main/ets/domain/model/MultipleCommandsFormData';
import SingleCommandFormData from '../main/ets/domain/model/SingleCommandFormData';
import { CommandEntryJsonObject, ExportJsonObject, SettingsJsonObject } from '../main/ets/domain/model/JsonObjects';
import { CommandRepository } from '../main/ets/domain/repository/CommandRepository';
import { FormBindingRepository } from '../main/ets/domain/repository/FormBindingRepository';
import { SettingsRepository } from '../main/ets/domain/repository/SettingsRepository';
import { TransactionBoundary } from '../main/ets/data/Database';
import { CommandService } from '../main/ets/domain/service/CommandService';
import { CommandImportService } from '../main/ets/domain/service/CommandImportService';

/**
 * B2 领域规则单测（设计 §6.1 的 U1–U9、U15）。四个假仓库把顺序、次数与失败注入到可控状态，
 * 断言的是业务结果（先解绑后删库、解绑失败则整体失败、导入被拒与回滚），不是实现细节。
 */

// 调用顺序台账：两张表的假仓库共写一份，用来判「先解绑、后删库」这类顺序规则
class CallLog {
  calls: string[] = [];

  record(call: string): void {
    this.calls.push(call);
  }

  indexOf(prefix: string): number {
    for (let i = 0; i < this.calls.length; i++) {
      if (this.calls[i].startsWith(prefix)) return i;
    }
    return -1;
  }

  count(prefix: string): number {
    let total = 0;
    for (const call of this.calls) {
      if (call.startsWith(prefix)) total++;
    }
    return total;
  }
}

class FakeCommandRepository implements CommandRepository {
  private log: CallLog;
  entries: CommandEntry[] = [];
  failDelete: boolean = false;
  failReplace: boolean = false;

  constructor(log: CallLog) {
    this.log = log;
  }

  async getByID(id: number): Promise<CommandEntry | null> {
    for (const entry of this.entries) {
      if (entry.id === id) return entry;
    }
    return null;
  }

  async list(): Promise<CommandEntry[]> {
    return this.entries;
  }

  async insert(entry: CommandEntry): Promise<number> {
    this.log.record(`insert:${entry.orderIndex}`);
    this.entries.push(entry);
    return this.entries.length;
  }

  async update(entry: CommandEntry): Promise<boolean> {
    this.log.record(`update:${entry.id}`);
    return true;
  }

  // 与真实 CommandDao 同形：写失败抛错，不靠返回值表达失败
  async deleteByID(id: number): Promise<boolean> {
    this.log.record(`delete:${id}`);
    if (this.failDelete) throw new Error('注入的写失败');
    return true;
  }

  async batchUpdateOrderIndices(entries: CommandEntry[]): Promise<boolean> {
    this.log.record(`reorder:${entries.length}`);
    return true;
  }

  async replaceAll(entries: CommandEntry[]): Promise<boolean> {
    this.log.record(`replace:${entries.length}`);
    if (this.failReplace) return false;

    this.entries = entries;
    return true;
  }
}

class FakeFormBindingRepository implements FormBindingRepository {
  private log: CallLog;
  singles: Array<[string, SingleCommandFormData]> = [];
  multiples: Array<[string, MultipleCommandsFormData]> = [];
  failRemove: boolean = false;
  failClear: boolean = false;
  failUnbind: boolean = false;

  constructor(log: CallLog) {
    this.log = log;
  }

  async getSingle(formID: string): Promise<SingleCommandFormData | null> {
    for (const pair of this.singles) {
      if (pair[0] === formID) return pair[1];
    }
    return null;
  }

  async getMultiple(formID: string): Promise<MultipleCommandsFormData | null> {
    for (const pair of this.multiples) {
      if (pair[0] === formID) return pair[1];
    }
    return null;
  }

  async bindSingle(data: SingleCommandFormData): Promise<void> {
    this.log.record(`bindSingle:${data.formID}`);
  }

  async bindMultiple(data: MultipleCommandsFormData): Promise<void> {
    this.log.record(`bindMultiple:${data.formID}`);
  }

  async unbind(formID: string): Promise<void> {
    this.log.record(`unbind:${formID}`);
    if (this.failUnbind) throw new Error('注入的写失败');
  }

  async listSingle(): Promise<Array<[string, SingleCommandFormData]>> {
    return this.singles;
  }

  async listMultiple(): Promise<Array<[string, MultipleCommandsFormData]>> {
    return this.multiples;
  }

  async updateByShortcut(entry: CommandEntry): Promise<string[]> {
    this.log.record(`updateByShortcut:${entry.id}`);
    const affected: string[] = [];
    for (const pair of this.singles) {
      if (pair[1].shortcutID === entry.id) affected.push(pair[0]);
    }
    return affected;
  }

  async removeByShortcutID(shortcutID: number): Promise<string[]> {
    this.log.record(`removeByShortcutID:${shortcutID}`);
    if (this.failRemove) throw new Error('注入的写失败');

    const affected: string[] = [];
    for (const pair of this.singles) {
      if (pair[1].shortcutID === shortcutID) {
        affected.push(pair[0]);
        // 与真实 store 同形：只有命中的卡片才真的调用 unbind
        await this.unbind(pair[0]);
      }
    }
    return affected;
  }

  async clearAll(): Promise<boolean> {
    this.log.record('clearAll');
    return !this.failClear;
  }
}

class FakeSettingsRepository implements SettingsRepository {
  private log: CallLog;
  values: Map<string, string> = new Map<string, string>();
  failReplace: boolean = false;

  constructor(log: CallLog) {
    this.log = log;
  }

  async get(key: string): Promise<string> {
    const value = this.values.get(key);
    return value === undefined ? '' : value;
  }

  async save(key: string, value: string): Promise<boolean> {
    this.values.set(key, value);
    return true;
  }

  async areComplete(): Promise<boolean> {
    return true;
  }

  async replaceAll(entries: Array<[string, string]>): Promise<boolean> {
    this.log.record(`settingsReplace:${entries.length}`);
    if (this.failReplace) return false;
    return true;
  }
}

class FakeTransaction implements TransactionBoundary {
  private log: CallLog;

  constructor(log: CallLog) {
    this.log = log;
  }

  beginTransaction(): void {
    this.log.record('begin');
  }

  commitTransaction(): void {
    this.log.record('commit');
  }

  rollBackTransaction(): void {
    this.log.record('rollback');
  }
}

// 一套便利构造：所有依赖都指向同一份调用台账
class Fixture {
  log: CallLog = new CallLog();
  commands: FakeCommandRepository = new FakeCommandRepository(this.log);
  bindings: FakeFormBindingRepository = new FakeFormBindingRepository(this.log);
  settings: FakeSettingsRepository = new FakeSettingsRepository(this.log);
  transaction: FakeTransaction = new FakeTransaction(this.log);

  service(): CommandService {
    return new CommandService(this.commands, this.bindings);
  }

  importService(): CommandImportService {
    return new CommandImportService(this.commands, this.settings, this.bindings, this.transaction);
  }

  list(entries: CommandEntry[]): CommandEntryList {
    return new CommandEntryList(entries, this.commands, this.service(), this.importService());
  }
}

function boundSingleEntry(id: number, formID: string): CommandEntry {
  return new CommandEntry(id, '绑定中的指令', 'status', 0, 0, 0);
}

function singleBinding(formID: string, shortcutID: number): SingleCommandFormData {
  const data = new SingleCommandFormData(formID, false);
  data.shortcutID = shortcutID;
  data.nickname = '旧昵称';
  data.command = 'status';
  return data;
}

function legalImportJson(command: string): ExportJsonObject {
  return new ExportJsonObject(
    new SettingsJsonObject('http://127.0.0.1:32123', 'password'),
    [new CommandEntryJsonObject('合法条目', command, 0, 0, 0)]
  );
}

export default function domainRulesTest() {
  describe('domainRulesTest', () => {
    // U1：删除被单卡绑定的指令 → 先 unbind，后 deleteByID，受影响集合含该 formID
    it('deleteBoundEntryUnbindsBeforeDelete', 0, async () => {
      const fixture = new Fixture();
      const entry = boundSingleEntry(3, 'form-single-1');
      fixture.bindings.singles.push(['form-single-1', singleBinding('form-single-1', 3)]);

      const result = await fixture.service().deleteEntry(3);

      expect(result.ok).assertTrue();
      expect(fixture.log.indexOf('removeByShortcutID:3') < fixture.log.indexOf('delete:3')).assertTrue();
      expect(fixture.log.count('unbind:form-single-1')).assertEqual(1);
      expect(result.affected.get('single')!.indexOf('form-single-1') >= 0).assertTrue();
      expect(entry.id).assertEqual(3);
    });

    // U2：删除无绑定的指令 → 没有任何卡片被解绑，deleteByID 恰好一次
    it('deleteUnboundEntrySkipsUnbind', 0, async () => {
      const fixture = new Fixture();

      const result = await fixture.service().deleteEntry(9);

      expect(result.ok).assertTrue();
      expect(fixture.log.count('unbind:')).assertEqual(0);
      expect(fixture.log.count('delete:9')).assertEqual(1);
    });

    // U3：条目改为需要自定义输入 → 解绑该指令的全部绑定（AIR 与 IIR 两个判据各一次）
    it('updateToRequireInputUnbinds', 0, async () => {
      const fixture = new Fixture();
      fixture.bindings.singles.push(['form-single-2', singleBinding('form-single-2', 4)]);
      fixture.bindings.singles.push(['form-single-2b', singleBinding('form-single-2b', 4)]);

      // accountInputRequired = 1
      const airEntry = new CommandEntry(4, '改成要账号', 'say {{account}}', 0, 1, 0);
      const airResult = await fixture.service().updateEntry(airEntry);
      expect(airResult.ok).assertTrue();
      expect(fixture.log.count('removeByShortcutID:4')).assertEqual(1);
      expect(fixture.log.count('updateByShortcut')).assertEqual(0);

      // idInputRequired = 1
      const iirEntry = new CommandEntry(4, '改成要 ID', 'say {{id}}', 0, 0, 1);
      const iirResult = await fixture.service().updateEntry(iirEntry);
      expect(iirResult.ok).assertTrue();
      expect(fixture.log.count('removeByShortcutID:4')).assertEqual(2);
      expect(fixture.log.count('updateByShortcut')).assertEqual(0);
    });

    // X1 的失败分支：解绑失败则删除失败，且不碰指令表
    it('deleteFailsWhenUnbindFails', 0, async () => {
      const fixture = new Fixture();
      fixture.bindings.singles.push(['form-single-4', singleBinding('form-single-4', 6)]);
      fixture.bindings.failRemove = true;

      const result = await fixture.service().deleteEntry(6);

      expect(result.ok).assertFalse();
      expect(result.unbindFailed).assertTrue();
      expect(fixture.log.count('delete:6')).assertEqual(0);
    });

    // 删除的第二道关：解绑成功但删库失败 → 结果失败
    it('deleteFailsWhenRepositoryFails', 0, async () => {
      const fixture = new Fixture();
      fixture.commands.failDelete = true;

      const result = await fixture.service().deleteEntry(7);

      expect(result.ok).assertFalse();
      expect(result.unbindFailed).assertFalse();
    });

    // U4：仅昵称变化 → 不解绑，返回受影响 formID 供刷新
    it('updateNicknameOnlyRefreshesBindings', 0, async () => {
      const fixture = new Fixture();
      fixture.bindings.singles.push(['form-single-3', singleBinding('form-single-3', 5)]);

      const entry = new CommandEntry(5, '新昵称', 'status', 0, 0, 0);
      const result = await fixture.service().updateEntry(entry);

      expect(result.ok).assertTrue();
      expect(fixture.log.count('removeByShortcutID')).assertEqual(0);
      expect(fixture.log.count('updateByShortcut:5')).assertEqual(1);
      expect(result.affected.get('single')!.indexOf('form-single-3') >= 0).assertTrue();
    });

    // U5：列表为空新增 → orderIndex = 0（1.7.1 冻结口径，见 §5 登记）
    it('addFirstEntryStartsAtZero', 0, async () => {
      const fixture = new Fixture();
      const model = fixture.list([]);

      const entry = new CommandEntry(0, '第一条', 'status', -1, 0, 0);
      const success = await model.addCommandEntry(entry);

      expect(success).assertTrue();
      expect(entry.orderIndex).assertEqual(0);
    });

    // U6：列表最大 orderIndex = 7 → 新增得 8
    it('addEntryAppendsAfterMaxOrderIndex', 0, async () => {
      const fixture = new Fixture();
      const existing = [
        new CommandEntry(1, 'a', 'status', 0, 0, 0),
        new CommandEntry(2, 'b', 'status', 7, 0, 0)
      ];
      const model = fixture.list(existing);

      const entry = new CommandEntry(0, '新条目', 'status', -1, 0, 0);
      await model.addCommandEntry(entry);

      expect(entry.orderIndex).assertEqual(8);
    });

    // U7：顶层缺 Settings → 拒绝，原因点名该键
    it('rejectImportWithoutSettings', 0, async () => {
      const fixture = new Fixture();
      const broken = JSON.parse('{"CommandEntryList": []}') as ExportJsonObject;

      const validation = fixture.importService().validate(broken);

      expect(validation.ok).assertFalse();
      expect(validation.reason.indexOf('Settings') >= 0).assertTrue();
      expect(fixture.log.count('begin')).assertEqual(0);
      expect(fixture.log.count('replace')).assertEqual(0);
    });

    // U8：Command 为空串 → 拒绝，原因点名第几条与哪个字段
    it('rejectImportWithEmptyCommand', 0, async () => {
      const fixture = new Fixture();
      const json = legalImportJson('   ');

      const validation = fixture.importService().validate(json);

      expect(validation.ok).assertFalse();
      expect(validation.reason.indexOf('第 1 条') >= 0).assertTrue();
      expect(validation.reason.indexOf('Command') >= 0).assertTrue();
    });

    // U9：合法 JSON → 同一事务内整体替换两张表；替换失败则回滚
    it('importReplacesBothTablesInOneTransaction', 0, async () => {
      const fixture = new Fixture();

      const result = await fixture.importService().importData(legalImportJson('status'));

      expect(result.ok).assertTrue();
      expect(result.bindingsCleared).assertTrue();
      expect(fixture.log.count('begin')).assertEqual(1);
      expect(fixture.log.count('commit')).assertEqual(1);
      expect(fixture.log.count('rollback')).assertEqual(0);
      expect(fixture.log.indexOf('begin') < fixture.log.indexOf('settingsReplace:2')).assertTrue();
      expect(fixture.log.indexOf('settingsReplace:2') < fixture.log.indexOf('replace:1')).assertTrue();
      expect(fixture.log.indexOf('replace:1') < fixture.log.indexOf('commit')).assertTrue();
    });

    // U9 后半：替换失败 → 回滚，并如实报失败
    it('importRollsBackWhenReplaceFails', 0, async () => {
      const fixture = new Fixture();
      fixture.commands.failReplace = true;

      const result = await fixture.importService().importData(legalImportJson('status'));

      expect(result.ok).assertFalse();
      expect(fixture.log.count('rollback')).assertEqual(1);
      expect(fixture.log.count('commit')).assertEqual(0);
    });

    // U15：导入成功但清空绑定失败 → 结果为失败，原因含「卡片绑定未清理」
    it('importReportsBindingClearFailure', 0, async () => {
      const fixture = new Fixture();
      fixture.bindings.failClear = true;

      const result = await fixture.importService().importData(legalImportJson('status'));

      expect(result.ok).assertFalse();
      expect(result.bindingsCleared).assertFalse();
      expect(result.reason.indexOf('卡片绑定未清理') >= 0).assertTrue();
    });
  });
}
