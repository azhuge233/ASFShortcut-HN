import { systemDateTime } from '@kit.BasicServicesKit';
import { picker, fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { buffer } from '@kit.ArkTS';

import Logger from '../../common/utils/Logger';
import { ExportJsonObject } from '../../domain/model/JsonObjects';

const LOG_TAG: string = '[TransferFiles]';

/**
 * 备份文件的读写与解析：`saveToFile` / `pickFile` / `readFile` / `parseData`，签名与行为与 1.7.1 一致。
 * `@kit.AbilityKit` 只用到 `common.UIAbilityContext` 这个类型——
 * picker 要一个窗口上下文，而 `domain/` 与 `viewmodel/` 都不许 import 该 kit（设计 §1.5 规则 1）。
 */
class TransferFiles {
    // 导出功能
    // 保存到文件
    public async saveToFile(json: string, context: common.UIAbilityContext): Promise<boolean> {
        let jsonFilename = `ASFShortcut-backup-${this.getDate()}.json`;

        const documentSaveOptions = new picker.DocumentSaveOptions();
        documentSaveOptions.newFileNames = [jsonFilename];
        documentSaveOptions.fileSuffixChoices = [".json"];

        const documentViewPicker = new picker.DocumentViewPicker(context);

        try {
            const uris = await documentViewPicker.save(documentSaveOptions);
            Logger.debug(LOG_TAG, `已选取保存路径: ${uris}`);

            if (uris.length > 0) {
                let savePath: string = uris[0];
                let jsonFile: fs.File | null = null;

                try {
                    jsonFile = fs.openSync(savePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
                    let writeLen = fs.writeSync(jsonFile.fd, json);
                    Logger.debug(LOG_TAG, `配置文件已保存, 路径: ${jsonFile.path}, 写入长度: ${writeLen}`);
                    return true;
                } finally {
                    if (jsonFile) {
                        try {
                            fs.closeSync(jsonFile);
                        } catch (closeErr) {
                            Logger.error(LOG_TAG, `关闭导出文件失败, ${closeErr}`);
                        }
                    }
                }
            }

            Logger.warn(LOG_TAG, "没有选取保存路径");
            return false;
        } catch (err) {
            Logger.error(LOG_TAG, `保存失败, ${err}`);
            throw new Error("备份导出失败");
        }
    }

    // 导入功能
    // 选择备份文件路径
    public async pickFile(context: common.UIAbilityContext): Promise<string[]> {
        const documentSelectOptions = new picker.DocumentSelectOptions();
        documentSelectOptions.maxSelectNumber = 1;
        documentSelectOptions.fileSuffixFilters = [".json"];

        const documentViewPicker = new picker.DocumentViewPicker(context);
        const uris = await documentViewPicker.select(documentSelectOptions);

        Logger.debug(LOG_TAG, `选取文件: ${uris}`);
        return uris;
    }

    // 导入功能
    // 读取备份文件
    public async readFile(uri: string): Promise<string | undefined> {
        let file: fs.File | null = null;
        try {
            file = fs.openSync(uri, fs.OpenMode.READ_ONLY);

            let fileStat = fs.statSync(file.fd);
            let fileSize = fileStat.size;
            Logger.debug(LOG_TAG, `文件大小: ${fileSize} 字节`);

            // 读取文件
            // cannot use readText(Sync), throws 13900002 error(No such file or directory)
            let arrayBuffer = new ArrayBuffer(fileSize);
            let readLen = fs.readSync(file.fd, arrayBuffer);

            Logger.debug(LOG_TAG, `从文件读取 ${readLen} 字节`);
            if (readLen !== fileSize) Logger.warn(LOG_TAG,
                `应读取 ${fileSize} 字节, 但实际读取 ${readLen}`);

            let jsonString = buffer.from(arrayBuffer, 0, readLen).toString();

            Logger.debug(LOG_TAG, `读取成功, 内容长度: ${jsonString.length}`);
            return jsonString;
        } catch (err) {
            Logger.error(LOG_TAG, `文件读取失败, ${err}`);
            return undefined;
        } finally {
            if (file) {
                try {
                    fs.closeSync(file);
                } catch (closeErr) {
                    Logger.error(LOG_TAG, `关闭导入文件失败, ${closeErr}`);
                }
            }
        }
    }

    // 导入功能
    // 解析 json 字符串到 ExportJsonObject 对象
    public async parseData(jsonStr: string): Promise<ExportJsonObject> {
        try {
            const exportJson = JSON.parse(jsonStr) as ExportJsonObject;

            if (Array.isArray(exportJson.CommandEntryList)) {
                Logger.debug(LOG_TAG, `数据解析成功, 指令列表长度: ${exportJson.CommandEntryList.length}`);
                return exportJson;
            } else throw new Error("解析失败，指令列表非数组");
        } catch (err) {
            Logger.error(LOG_TAG, `数据解析失败, ${err}`);
            throw new Error(`数据解析失败: ${err}`);
        }
    }

    // 获取时间（毫秒）
    private getDate(): string {
        let date = new Date(systemDateTime.getTime());

        const formattedTime = `${date.getTime().toString()}`;
        Logger.debug(LOG_TAG, formattedTime);

        return formattedTime;
    }
}

export default new TransferFiles();
