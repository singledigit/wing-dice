bring cloud;
bring http;
bring math;
bring ex;
bring util;

struct DiceServiceOptions {
  chanceOfFailure: num?; /** rate of simulated failure for the service */
}

class DiceService {
    url: str; /** the url of the dice service */
  
    init(opts: DiceServiceOptions?) {
      let api = new cloud.Api();
      this.url = api.url;

      let table = new ex.Table(
        name: "dice_rolls",
        primaryKey: "id",
        columns: {
          "name" => ex.ColumnType.STRING,
          "roll" => ex.ColumnType.NUMBER,
          "created" => ex.ColumnType.DATE
        }
      );
  
      let errorResponse = inflight (status: num, message: str): cloud.ApiResponse => {
        return cloud.ApiResponse {
          status: status,
          headers: { "content-type" => "application/json" },
          body: Json.stringify({ error: message }),
        };
      };
        
      api.post("/roll", inflight (req: cloud.ApiRequest): cloud.ApiResponse => {
        let now = datetime.utcNow().toIso();

        if DiceService.simulateFailure(opts?.chanceOfFailure) {
            log("simulated error");
            return errorResponse(400, "simulated error");
        }

        let var name: str = "";

        if let nameFromJson = Json.tryParse(req.body)?.tryGet("name"){
            name = nameFromJson.asStr();
        } else {
            return errorResponse(400, "Body parameter 'name' is required");
        }
      
        if !(name.length >= 2 && name.length <= 30) {
          return errorResponse(400, "Body parameter 'name' must be between 2 and 30 characters");
        }
      
        let diceRoll = math.floor(math.random(6)) + 1;
        log("${name}=${diceRoll}");

        table.insert(util.nanoid(),{
          "name": name,
          "roll": diceRoll,
          "created": now
        });
  
        return cloud.ApiResponse {
          status: 200,
          headers: { "content-type" => "application/json" },
          body: Json.stringify({ 
            name: name,
            diceRoll: diceRoll,
            created: now
          })
        };
      });

      api.get("/rolls", inflight (req: cloud.ApiRequest): cloud.ApiResponse => {
        let results = table.list();

        return cloud.ApiResponse {
          status: 200,
          headers: { "content-type" => "application/json" },
          body: Json.stringify(results)
        };
      });
    }
  
    static inflight simulateFailure(chanceOfFailure: num?):bool {
      let rate = chanceOfFailure ?? 0;
  
      // random sample between 0 to 100
      let sample = math.random(100);
  
      // if rate == 0 then we never fail, if rate == 100 we always fail
      if sample < rate {
        return true;
      }

      return false;
    }
  }


let service = new DiceService();

//////////////////////
// Tests / / / / / ///
//////////////////////

let testData = Json.stringify({"name":"Fred"});

test "DiceService - roll die" {
  let roll = (): num => {
    let response = http.post("${service.url}/roll", body: testData);
    assert(response.ok);
    let result = Json.parse(response.body ?? "").get("diceRoll").asNum();
    return result;
  };

  // lets do 200 rolls and check the stats
  let results = MutMap<num>{};
  let samples = 300;
  for i in 0..samples {
    let dice = roll();
    let key = "${dice}";
    let curr: num? = results.get(key);
    results.set(key, (curr ?? 0) + 1);
  }
  assert(results.size() == 6);

  // 15% tolerance
  let tolerance = samples * 0.15;
  for k in results.keys() {
    let count = results.get(k);
    let avg = samples / 6;
    assert(count >= (avg - tolerance / 2));
    assert(count <= (avg + tolerance / 2));
  }
}

test "DiceService - save to table" {
  let rollResponse = http.post("${service.url}/roll", body: testData);
  let dbResponse = http.get("${service.url}/rolls");
  let results = Json.parse(dbResponse.body ?? "");
  assert(results.getAt(0).get("name").asStr() == "Fred");
}

test "DiceService - missing name" {
  let response = http.post("${service.url}/roll");
  assert(response.status == 400);
  assert(Json.parse(response.body ?? "").get("error").asStr() == "Body parameter 'name' is required");
}

test "DiceService - name too short" {
  let response = http.post("${service.url}/roll", body: Json.stringify({"name":"b"}));
  assert(response.status == 400);
  assert(Json.parse(response.body ?? "").get("error").asStr() == "Body parameter 'name' must be between 2 and 30 characters");
}

test "simulateFailure() - default is never fail" {
  for i in 0..1000 {
    DiceService.simulateFailure();
  }
}

test "simulateFailure() - 50% failure" {
  let var failures = 0;
  let samples = 1000;

  for i in 0..samples {
    if !DiceService.simulateFailure(50) {
      failures = failures + 1;
    }
  }

  let actualRate = failures / samples * 100;
  assert(actualRate > 45 && actualRate < 55);
}