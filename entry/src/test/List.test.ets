import localUnitTest from './LocalUnit.test';
import cardRunSessionTest from './CardRunSession.test';
import domainRulesTest from './DomainRules.test';
import viewModelsTest from './ViewModels.test';

export default function testsuite() {
  localUnitTest();
  cardRunSessionTest();
  domainRulesTest();
  viewModelsTest();
}
