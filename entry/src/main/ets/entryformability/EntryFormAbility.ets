import { formBindingData, FormExtensionAbility, formInfo } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';

import Logger from '../common/utils/Logger';

export default class EntryFormAbility extends FormExtensionAbility {
    private LOG_TAG = '[EntryFormAbility]';

    onAddForm(want: Want) {
        // Called to return a FormBindingData object.
        Logger.warn(this.LOG_TAG, `${want?.parameters?.["ohos.extra.param.key.form_identity"]} onAddForm()`);

        const formData = '';
        return formBindingData.createFormBindingData(formData);
    }

    onCastToNormalForm(formId: string) {
        // Called when the form provider is notified that a temporary form is successfully
        // converted to a normal form.
        Logger.warn(this.LOG_TAG, `${formId} onCastToNormalForm()`);
    }

    onUpdateForm(formId: string) {
        // Called to notify the form provider to update a specified form.
        Logger.warn(this.LOG_TAG, `${formId} onUpdateForm()`);
    }

    onFormEvent(formId: string, message: string) {
        // Called when a specified message event defined by the form provider is triggered.
        Logger.warn(this.LOG_TAG, `${formId} onFormEvent()`);
    }

    onRemoveForm(formId: string) {
        // Called to notify the form provider that a specified form has been destroyed.
        Logger.warn(this.LOG_TAG, `${formId} onRemoveForm()`);
    }

    onAcquireFormState(want: Want) {
        // Called to return a {@link FormState} object.
        Logger.warn(this.LOG_TAG, `${want?.parameters?.["ohos.extra.param.key.form_identity"]} onAcquireFormState()`);

        return formInfo.FormState.READY;
    }
}