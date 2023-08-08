bring "./dice.w" as dice;
bring http;
bring math;

let service = new dice.DiceService();
let failingDiceService = new dice.DiceService(chanceOfFailure: 100) as "failingDiceService";

test "simulateFailure() - 50% failure" {
  let var failures = 0;
  let samples = 1000;

  for i in 0..samples {
    try {
      dice.DiceService.simulateFailure(50);
    } catch {
      failures = failures + 1;
    }
  }

  let actualRate = failures / samples * 100;
  assert(actualRate > 45 && actualRate < 55);
}