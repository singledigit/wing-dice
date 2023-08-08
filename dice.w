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
      let table = new ex.Table(
        name: "employees",
        primaryKey: "id",
        columns: {
          "name" => ex.ColumnType.STRING,
          "roll" => ex.ColumnType.NUMBER
        }
      );
 
      this.url = api.url;
  
      let errorResponse = inflight (status: num, message: str): cloud.ApiResponse => {
        return cloud.ApiResponse {
          status: status,
          headers: { "content-type" => "application/json" },
          body: Json.stringify({ error: message }),
        };
      };
        
      api.post("/roll", inflight (req: cloud.ApiRequest): cloud.ApiResponse => {

        if DiceService.simulateFailure(opts?.chanceOfFailure) {
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

        table.insert(util.nanoid(),{"name": name, "roll": diceRoll });
  
        return cloud.ApiResponse {
          status: 200,
          headers: { "content-type" => "application/json" },
          body: Json.stringify({ 
            name: name,
            diceRoll: diceRoll
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