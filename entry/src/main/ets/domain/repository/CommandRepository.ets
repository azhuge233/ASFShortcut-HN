import CommandEntry from '../model/CommandEntry';

/**
 * 指令表（`COMMANDENTRIES`）的存取接口。data 层实现、领域层持有（设计 §2.2、§2.3）。
 */
export interface CommandRepository {
    getByID(id: number): Promise<CommandEntry | null>;

    list(): Promise<CommandEntry[]>;

    insert(entry: CommandEntry): Promise<number>;

    update(entry: CommandEntry): Promise<boolean>;

    deleteByID(id: number): Promise<boolean>;

    batchUpdateOrderIndices(entries: CommandEntry[]): Promise<boolean>;

    /** 整表替换：导入事务体与「清空全部指令」共用；事务边界由调用方组织 */
    replaceAll(entries: CommandEntry[]): Promise<boolean>;
}
