import { describe, it, expect } from '@ohos/hypium';

import CommandEntry from '../main/ets/domain/model/CommandEntry';
import CommandEntryList from '../main/ets/domain/model/CommandEntryList';
import CommandListViewModel from '../main/ets/viewmodel/CommandListViewModel';

/**
 * B3 的 ViewModel 单测（设计 §6.1 的 U13、U14、U16）。
 *
 * 断言的是 VM 的状态与业务结果：拖拽成功即持久化、持久化失败按数据库顺序回滚、
 * 读库失败置错误态且不把列表当空。聚合根用子类替身，把「读失败 / 写失败」注入到可控状态；
 * 其余端口在本文件用不到（VM 只在导入与执行路径上取它们），因此走默认装配。
 */

// 一次 move 的落库在后台完成，`move` 本身同步返回（`List.onMove` 要求同步）。
// 替身里每个 await 都立刻结算，所以排空微任务队列即可确定性地等到落库结束——不用计时器。
async function settle(): Promise<void> {
  for (let i = 0; i < 20; i++) await Promise.resolve();
}

class FakeAggregate extends CommandEntryList {
  loadFails: boolean = false;
  persistFails: boolean = false;
  persisted: Array<CommandEntry> = [];

  private store: Array<CommandEntry> = [];

  constructor(seed: Array<CommandEntry>) {
    super([]);
    this.store = seed;
  }

  async loadCommandEntries(): Promise<boolean> {
    if (this.loadFails) throw new Error('注入的读失败');

    this.commandEntries = this.store.map(
      (entry: CommandEntry) => new CommandEntry(entry.id, entry.nickname, entry.command, entry.orderIndex,
        entry.accountInputRequired, entry.idInputRequired)
    );
    return true;
  }

  async updateEntriesOrder(entries: Array<CommandEntry>): Promise<boolean> {
    this.persisted = entries;
    if (this.persistFails) return false;

    for (const entry of entries) {
      for (const stored of this.store) {
        if (stored.id === entry.id) stored.orderIndex = entry.orderIndex;
      }
    }
    this.store.sort((a: CommandEntry, b: CommandEntry) => a.orderIndex - b.orderIndex);
    return true;
  }
}

function seed(): Array<CommandEntry> {
  return [
    new CommandEntry(1, 'a', 'status', 0, 0, 0),
    new CommandEntry(2, 'b', 'help', 1, 0, 0),
    new CommandEntry(3, 'c', 'stop', 2, 0, 0)
  ];
}

function nicknames(vm: CommandListViewModel): string {
  return vm.entries.map((item) => item.nickname).join(',');
}

export default function viewModelsTest() {
  describe('ViewModels', () => {
    // U13：拖拽排序成功 → 顺序更新并持久化
    it('movePersistsNewOrder', 0, async () => {
      const aggregate = new FakeAggregate(seed());
      const vm = new CommandListViewModel(aggregate);
      await vm.loadEntries();

      expect(vm.move(0, 2)).assertTrue();
      await settle();

      expect(aggregate.persisted.length).assertEqual(3);
      expect(aggregate.persisted[0].nickname).assertEqual('b');
      expect(aggregate.persisted[0].orderIndex).assertEqual(0);
      expect(aggregate.persisted[2].nickname).assertEqual('a');
      expect(aggregate.persisted[2].orderIndex).assertEqual(2);
      expect(nicknames(vm)).assertEqual('b,c,a');
    });

    // U14：拖拽排序持久化失败 → 顺序回滚为数据库顺序，并通知页面
    it('moveRollsBackWhenPersistFails', 0, async () => {
      const aggregate = new FakeAggregate(seed());
      aggregate.persistFails = true;

      const vm = new CommandListViewModel(aggregate);
      let notified = 0;
      vm.onMoveFailed = () => {
        notified++;
      };
      await vm.loadEntries();

      expect(vm.move(0, 2)).assertTrue();
      await settle();

      expect(nicknames(vm)).assertEqual('a,b,c');
      expect(notified).assertEqual(1);
    });
    // 搜索过滤下的拖拽：可见下标要映回全量位置，不能把另一条的顺序改掉（评审第 1 条的回归守卫）
    it('moveUnderFilterReordersVisibleEntries', 0, async () => {
      const aggregate = new FakeAggregate([
        new CommandEntry(1, 'one', 'status', 0, 0, 0),
        new CommandEntry(2, 'two', 'others', 1, 0, 0),
        new CommandEntry(3, 'three', 'status', 2, 0, 0),
        new CommandEntry(4, 'four', 'others', 3, 0, 0)
      ]);
      const vm = new CommandListViewModel(aggregate);
      await vm.loadEntries();
      vm.setKeyword('status');
      expect(nicknames(vm)).assertEqual('one,three');

      expect(vm.move(0, 1)).assertTrue();
      await settle();

      // 可见序换成 three,one；不可见的 two/four 相对顺序不变，退出的是「把 one 插到 three 之后」
      // （旧实现按可见下标 splice 全量，得到 two,one,three,four —— 动错了一条，本断言挡住它）
      expect(aggregate.persisted.map((entry) => entry.nickname).join(',')).assertEqual('two,three,one,four');
      expect(nicknames(vm)).assertEqual('three,one');
    });


    // U16：列表仓库读抛错 → VM 置 loadError，不把列表当空
    it('loadFailureSetsErrorState', 0, async () => {
      const aggregate = new FakeAggregate(seed());
      const vm = new CommandListViewModel(aggregate);

      await vm.loadEntries();
      expect(vm.entries.length).assertEqual(3);
      expect(vm.loadError).assertEqual('');

      aggregate.loadFails = true;
      await vm.loadEntries();

      expect(vm.loadError.length > 0).assertTrue();
      expect(vm.entries.length).assertEqual(3);
      expect(vm.isEmpty()).assertFalse();

      aggregate.loadFails = false;
      await vm.retryLoad();

      expect(vm.loadError).assertEqual('');
      expect(vm.entries.length).assertEqual(3);
    });
  });
}
