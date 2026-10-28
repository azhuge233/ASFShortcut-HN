import localUnitTest from './LocalUnit.test';
import cardRunSessionTest from './CardRunSession.test';

export default function testsuite() {
  localUnitTest();
  cardRunSessionTest();
}
