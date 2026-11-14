import localUnitTest from './LocalUnit.test';
import cardRunSessionTest from './CardRunSession.test';
import domainRulesTest from './DomainRules.test';

export default function testsuite() {
  localUnitTest();
  cardRunSessionTest();
  domainRulesTest();
}
