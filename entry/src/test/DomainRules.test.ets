import { describe, it, expect } from '@ohos/hypium';

import CommandEntry from '../main/ets/domain/model/CommandEntry';
import CommandEntryList from '../main/ets/domain/model/CommandEntryList';
import MultipleCommandsFormData from '../main/ets/domain/model/MultipleCommandsFormData';
import SingleCommandFormData from '../main/ets/domain/model/SingleCommandFormData';
import { CommandEntryJsonObject, ExportJsonObject, SettingsJsonObject } from '../main/ets/domain/model/JsonObjects';
import { CommandRepository } from '../main/ets/domain/repository/CommandRepository';
import { CardPublisher } from '../main/ets/domain/repository/CardPublisher';
import { FormBindingRepository } from '../main/ets/domain/repository/FormBindingRepository';
import { SettingsRepository } from '../main/ets/domain/repository/SettingsRepository';
import { TransactionBoundary } from '../main/ets/data/Database';
import { CardAdapter, CardKind, CardRunRequest, CardTerminal } from '../main/ets/domain/card/CardAdapter';
import { CardRunPipeline } from '../main/ets/domain/card/CardRunPipeline';
import { CardRunSession, RunToken } from '../main/ets/domain/card/CardRunSession';
import { MultipleCardAdapter } from '../main/ets/domain/card/MultipleCardAdapter';
import { SingleCardAdapter } from '../main/ets/domain/card/SingleCardAdapter';
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

// 记录一次终态写入的判据：pipeline 交给 adapter 的结局，以及据此选出的文案
class RecordedTerminal {
  formID: string = '';
  cancelled: boolean = false;
  payload: string | null = null;
  text: string = '';
}

// 假的卡片类型实现：只记录 pipeline 调了哪些步骤、按什么结局写终态
class RecordingCardAdapter implements CardAdapter {
  readonly kind: CardKind = 'single';

  earlyWrites: string[] = [];
  refreshWrites: string[] = [];
  terminals: RecordedTerminal[] = [];

  // 早写运行态时抛错：验证「写失败也要落到终态」，不让会话挂在运行态
  failEarlyWrite: boolean = false;
  // 早写运行态时要做的事（用例用它模拟「早写期间就被取消」）
  onEarlyWrite: (() => void) | null = null;

  parseRunRequest(params: Record<string, Object>): CardRunRequest | null {
    const formID: string = params['formID'] as string;
    return formID ? new CardRunRequest(formID) : null;
  }

  async writeRunningEarly(req: CardRunRequest): Promise<void> {
    if (this.onEarlyWrite) this.onEarlyWrite();
    if (this.failEarlyWrite) throw new Error('注入的早写失败');

    this.earlyWrites.push(req.formID);
  }

  async refreshRunningFromBinding(req: CardRunRequest): Promise<void> {
    // 与真实 adapter 同形：会话不活就不写运行态（模块档 §2.6 末段）
    if (!req.isActive()) return;
    this.refreshWrites.push(req.formID);
  }

  async writeTerminal(formID: string, outcome: CardTerminal): Promise<boolean> {
    const record = new RecordedTerminal();
    record.formID = formID;
    record.cancelled = outcome.cancelled;
    record.payload = outcome.payload;
    record.text = outcome.text('已取消', '执行失败');
    this.terminals.push(record);

    return true;
  }

  // pipeline 只在「无在跑会话」的取消里调它；本套用例不断言它（那条路要先初始化数据依赖）
  async writeFallbackTerminal(formID: string): Promise<void> {
  }
}

// 假的卡片写出口：分开记录 publish 与 publishWithRetry，判 adapter 走的是哪条既有口径
class RecordingPublisher implements CardPublisher {
  singleWrites: SingleCommandFormData[] = [];
  multipleWrites: MultipleCommandsFormData[] = [];
  retriedFormIDs: string[] = [];

  async publish(formID: string, data: SingleCommandFormData | MultipleCommandsFormData | null): Promise<boolean> {
    if (data instanceof SingleCommandFormData) this.singleWrites.push(data);
    else if (data instanceof MultipleCommandsFormData) this.multipleWrites.push(data);

    return true;
  }

  async publishWithRetry(formID: string, data: SingleCommandFormData | MultipleCommandsFormData): Promise<boolean> {
    this.retriedFormIDs.push(formID);

    if (data instanceof SingleCommandFormData) this.singleWrites.push(data);
    else if (data instanceof MultipleCommandsFormData) this.multipleWrites.push(data);

    return true;
  }
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

  // B4：运行编排的终态判定（U10–U12）与两个 adapter 的终态写入（设计 §5 的 adapter 断言）
  describe('cardRunPipelineTest', () => {
    // U10：用户取消后结果才到 → 终态文案取「已取消」，不是结果文本
    it('cancelWinsOverLateResult', 0, async () => {
      const adapter = new RecordingCardAdapter();
      const session = CardRunSession.getInstance();
      const pipeline = new CardRunPipeline(adapter, '[test]', session);

      const token: RunToken = session.begin('form-cancel-late');
      session.cancel('form-cancel-late');

      await pipeline.finishRun(token, '晚到的结果');

      expect(adapter.terminals.length).assertEqual(1);
      expect(adapter.terminals[0].cancelled).assertTrue();
      expect(adapter.terminals[0].text).assertEqual('已取消');
      expect(adapter.terminals[0].formID).assertEqual('form-cancel-late');
    });

    // U11：超时路径（payload = null、未取消）→ 终态文案取失败
    it('timeoutWritesFailedText', 0, async () => {
      const adapter = new RecordingCardAdapter();
      const session = CardRunSession.getInstance();
      const pipeline = new CardRunPipeline(adapter, '[test]', session);

      const token: RunToken = session.begin('form-timeout');

      await pipeline.finishRun(token, null);

      expect(adapter.terminals.length).assertEqual(1);
      expect(adapter.terminals[0].cancelled).assertFalse();
      expect(adapter.terminals[0].payload === null).assertTrue();
      expect(adapter.terminals[0].text).assertEqual('执行失败');
    });

    // 早写运行态失败：会话不能挂在运行态，必须落到一次终态写入
    it('earlyWriteFailureStillWritesTerminal', 0, async () => {
      const adapter = new RecordingCardAdapter();
      adapter.failEarlyWrite = true;
      const session = CardRunSession.getInstance();
      const pipeline = new CardRunPipeline(adapter, '[test]', session);

      await pipeline.run({ 'formID': 'form-early-fail' });

      expect(adapter.terminals.length).assertEqual(1);
      expect(adapter.terminals[0].cancelled).assertFalse();
      expect(adapter.terminals[0].text).assertEqual('执行失败');
    });

    // 早写运行态期间被取消：计时器与短时任务都要被归还，且只写一次「已取消」（U12 后半句）
    it('cancelDuringEarlyWriteReleasesTimerAndKeepAlive', 0, async () => {
      const adapter = new RecordingCardAdapter();
      const session = CardRunSession.getInstance();
      const pipeline = new CardRunPipeline(adapter, '[test]', session);

      adapter.onEarlyWrite = () => {
        pipeline.onBackground();            // 会话还活着 → 申请到短时任务
        session.cancel('form-cancel-early'); // 早写期间被取消 → 后续活性检查全部不通过
      };

      await pipeline.run({ 'formID': 'form-cancel-early' });

      expect(adapter.terminals.length).assertEqual(1);
      expect(adapter.terminals[0].cancelled).assertTrue();
      expect(adapter.terminals[0].text).assertEqual('已取消');
      expect(pipeline.isTimingOut()).assertFalse();
      expect(pipeline.hasKeepAlive()).assertFalse();
    });

    // U12：晚到结果（tryFinish 非当前会话）→ 不写卡片；旧运行不覆盖新卡片
    it('lateResultDoesNotWriteCard', 0, async () => {
      const adapter = new RecordingCardAdapter();
      const session = CardRunSession.getInstance();
      const pipeline = new CardRunPipeline(adapter, '[test]', session);

      const staleToken: RunToken = session.begin('form-late');
      const currentToken: RunToken = session.begin('form-late');

      await pipeline.finishRun(staleToken, '旧结果');
      expect(adapter.terminals.length).assertEqual(0);

      await pipeline.finishRun(currentToken, '新结果');
      expect(adapter.terminals.length).assertEqual(1);
      expect(adapter.terminals[0].text).assertEqual('新结果');
    });

    // 单卡 adapter：终态按 cancelled 优先 / payload 为 null 判失败 / 否则取结果，三支都写进领域模型
    it('singleAdapterSelectsTerminalText', 0, async () => {
      const publisher = new RecordingPublisher();
      const adapter = new SingleCardAdapter('已取消', '执行失败', new FakeFormBindingRepository(new CallLog()), publisher);

      await adapter.writeTerminal('form-s1', CardTerminal.of(true, '结果'));
      await adapter.writeTerminal('form-s1', CardTerminal.of(false, null));
      await adapter.writeTerminal('form-s1', CardTerminal.of(false, '结果'));

      expect(publisher.singleWrites.length).assertEqual(3);
      expect(publisher.singleWrites[0].runResult).assertEqual('已取消');
      expect(publisher.singleWrites[0].isRunning).assertFalse();
      expect(publisher.singleWrites[1].runResult).assertEqual('执行失败');
      expect(publisher.singleWrites[2].runResult).assertEqual('结果');
    });

    // 多卡 adapter：同一套终态判据，写入走 publishWithRetry（运行路径的既有重试口径）
    it('multipleAdapterSelectsTerminalText', 0, async () => {
      const publisher = new RecordingPublisher();
      const adapter = new MultipleCardAdapter('已取消', '执行失败', new FakeFormBindingRepository(new CallLog()), publisher);

      await adapter.writeTerminal('form-m1', CardTerminal.of(true, '结果'));
      await adapter.writeTerminal('form-m1', CardTerminal.of(false, null));

      expect(publisher.multipleWrites.length).assertEqual(2);
      expect(publisher.retriedFormIDs.length).assertEqual(2);
      expect(publisher.multipleWrites[0].runResult).assertEqual('已取消');
      expect(publisher.multipleWrites[0].isRunning).assertFalse();
      expect(publisher.multipleWrites[1].runResult).assertEqual('执行失败');
    });
  });
}
