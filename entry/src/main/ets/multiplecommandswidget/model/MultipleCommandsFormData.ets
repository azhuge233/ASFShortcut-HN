import WidgetCommand from "./WidgetCommand";

export default class MultipleCommandsFormData {
    formID: string = '';
    isInitialized: boolean = false;
    isRunning: boolean = false;

    commandList: Array<WidgetCommand> = [];

    runResult: string = '';

    constructor(formID: string, isInitialized: boolean) {
        this.formID = formID;
        this.isInitialized = isInitialized;
    }
}