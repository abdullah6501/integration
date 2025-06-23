// MR - 22OCT23 - Utility Class for RCustom Components

// MR 12NOV23 Function to replace Param Values in Input
// Thanks to https://www.npmjs.com/package/stringinject | https://github.com/tjcafferkey/stringinject
function stringInject(str, data) {
  if (typeof str === "string" && data instanceof Array) {
    return str.replace(/({\d})/g, function (i) {
      return data[i.replace(/{/, "").replace(/}/, "")];
    });
  } else if (typeof str === "string" && data instanceof Object) {
    if (Object.keys(data).length === 0) {
      return str;
    }

    for (let key in data) {
      return str.replace(/({([^}]+)})/g, function (i) {
        let key = i.replace(/{/, "").replace(/}/, "");
        if (!data[key]) {
          return i;
        }

        return data[key];
      });
    }
  } else if (
    (typeof str === "string" && data instanceof Array === false) ||
    (typeof str === "string" && data instanceof Object === false)
  ) {
    return str;
  } else {
    return false;
  }
}

function getQueryParameters() {
  var params = {};
  var search = location.search.substring(1);
  if (search) {
    params = JSON.parse(
      '{"' + search.replace(/&/g, '","').replace(/=/g, '":"') + '"}',
      (key, value) => {
        return key === "" ? value : decodeURIComponent(value);
      }
    );
  }
  return params;
}
// AP 09DEC24 - key changes

function nxtProcessQuestions(qList, sqOps, qbQueryResults, refFMList) {
  let questionList = [];

  // Works out the Options
  let sqOptions = new Map();
  for (const sq in sqOps) {
    sqOptions.set(sq, sqOps[sq]);
  }

  // Process the Question
  qList?.forEach((sq) => {
    sq.readOnly = false;
    // VD 01JAN24 - added radio too
    if (sq.type === "Dropdown" || sq.type === "Radio") {
      sq.options = sqOptions.get(sq.id).options;
    } else if (sq.type === "Book") {
      if (sq.qbReference && sq.qbReferenceQuestions) {
        let qData = JSON.parse(sq.qbReferenceQuestions);
        sq.questions = nxtProcessQuestions(
          qData.questionbook.subQuestions,
          qData.sqOptions,
          qbQueryResults,
          JSON.parse(sq["fieldsMeta"])
        );
      }
    }

    questionList?.push(
      nxtGetInputValue(
        JSON.parse(JSON.stringify(sq)),
        refFMList,
        qbQueryResults
      )
    );
  });

  return questionList;
}

function nxtGetInputValue(qObj, refFMList, queryResults) {
  // console.log('inside nxtUtils.nxtGetInputValue for ' + qObj['Name'] + ' and [' + queryResults?.length + '] records');

  refFMList?.forEach((rf) => {
    // Check Read Only Flag from Reference
    if (!qObj.readOnly && rf.readOnly) {
      qObj.readOnly = true;
    }
  });

  let retValue = null;

  const qType = qObj["type"];
  const fmString = qObj["fieldsMeta"];
  const refField = qObj["referenceField"];

  if (fmString) {
    // console.log('got fieldsmeta of ' + qType + ' type and using ' + refField + ' as ref field');
    let fmList = JSON.parse(fmString);

    // Process the Question Input
    fmList?.forEach((fld) => {
      // Check Read Only when the field is Only OUTPUT or Resultant
      if (!qObj.readOnly && fld.readOnly) {
        qObj.readOnly = true;
      }
    });

    if (queryResults && queryResults.length > 0) {
      let queryResult = queryResults[0];

      if (qType === "List") {
        retValue = {};
        fmList?.forEach((fld) => {
          if (fld.searchflag) {
            retValue = readFieldValue(fld, queryResult);
          }
        });
      } else if (qType === "Book") {
        console.log("qtype",qType);
        retValue = {};
        console.log("fmlist",JSON.stringify(fmList));
        fmList.forEach((fld) => {

          retValue = readFieldValue(fld, queryResult);
          console.log("query value",retValue);
        });
      }
      else if (qType === "Table") {
        console.log("qtype", qType);
        console.log("qobj", JSON.stringify(qObj));
    
        if (!qObj.title) {
            console.error("Error: Table name is missing.");
            return;
        }
    
        if (!qObj.subTitle) {
            console.error("Error: Record ID is missing.");
            return;
        }
    
        // Dynamically fetch field names
        let fieldNames = fmList.map(fld => fld.apiName).join(", ");
    
        // Properly inserting the record ID dynamically
        let recordId = qObj.subTitle; // Ensure this contains the actual ID
    
        let query = `SELECT ${fieldNames} FROM ${qObj.title} WHERE Sales_Order__r.Id = '${recordId}'`;
    
        console.log("Generated Query:", query);
    
        let retValue = {};
        fmList.forEach((fld) => {
            retValue = readFieldValue(fld, queryResult);
            console.log("Query value", retValue);
        });
    }
    

       else if (qType === "Date" && retValue == null && refField == "TODAY") {
        retValue = new Date().toLocaleDateString();
      } else {
        fmList.forEach((fld) => {
          // Check for Fields with Output or Resultant Flag
          if (fld.outputFlag || fld.resultantflag) {
            retValue = readFieldValue(fld, queryResult);
          }
        });
      }

      // console.log(retValue);
    } else {
      console.log("no query result to set the input field");
      // console.log(JSON.stringify(queryResults));
    }
  }

  qObj.input = retValue;
  return qObj;
}

function readFieldValue(fld, queryResult) {
  console.log("queryResult",JSON.stringify(queryResult));
  if (fld.ischild == true) {
    // console.log('inside nxtUtils.readFieldValue for ' + fld.childobjname + '.' + fld.childobjfldname + ' DB[' + fld.dbName + '] on the records');
    if (queryResult[fld.childobjname][fld.childobjfldname]) {
      return queryResult[fld.childobjname][fld.childobjfldname];
    }
  } else if (queryResult[fld.apiName]) {
    // console.log('inside nxtUtils.readFieldValue for ' + fld.apiName + ' DB[' + fld.dbName + '] on the records');
    return queryResult[fld.apiName];
  }

  // console.log('inside nxtUtils.readFieldValue. No value for ' + fld.apiName + ' DB[' + fld.dbName + '] on the records');
  return null;
}

// MR 05FEB24 - Function for the conditional visibility of the Question
function skipQuestion(dMeta, answer) {
  //console.log('rCustomUtility.skipQuestion with ' + JSON.stringify(answer));
  try {
    let val;
    let ops = [];
    if (answer.ansValue) {
      if (answer.typ == "Checkbox") {
        ops = ["IN"];
        // Handle Array Answers
      } else if (answer.typ == "Book") {
        ops = ["EQ", "GT", "LT", "NE"];
        // Handle Book Answer
      } else if (answer.typ == "List") {
        ops = ["EQ", "NE"];
        // Handle List
        val = answer.ansValue.arrItems[0].value.addlFldMap[dMeta.valueField];
      } else {
        ops = ["EQ", "NE"];
        val = answer.ansValue;
      }

      let lMap = new Map();
      // Logic Processing
      if (dMeta.logics) {
        dMeta.logics.forEach((l) => {
          console.log(l);
          console.log(
            "inside rCustomUtility.skipQuestion logic-" +
              l.order +
              " for " +
              val +
              " " +
              l.operation +
              " " +
              l.value
          );
          if (l.operation == "EQ" && val == l.value) {
            lMap.set(l.order, true);
          } else if (l.operation == "GT" && val > l.value) {
            lMap.set(l.order, true);
          } else if (l.operation == "LT" && val < l.value) {
            lMap.set(l.order, true);
          } else if (l.operation == "NE" && val != l.value) {
            lMap.set(l.order, true);
          } else {
            lMap.set(l.order, false);
          }
          console.log(lMap);
        });
      }

      return lMap.get(1);
    }
  } catch (e) {
    console.log(e);
  }

  return false;
}

// MR 06FEB24 - Simple Function
function isValidJSON(text) {
  try {
    JSON.parse(text);
    return true;
  } catch {
    return false;
  }
}

export {
  stringInject,
  getQueryParameters,
  nxtProcessQuestions,
  skipQuestion,
  isValidJSON
};