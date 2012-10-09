require(["dojo/_base/array"], function (array) {

var fieldHeader = ['index', 'name', 'optional', 'type', 'validateSpec'];

// Custom types

function _table2objects (data, columns) {
    if (columns === undefined) {
        columns = data.shift();
    }
    var objects = [], i, j, obj;
    for (i = 0; i < data.length; i++) {
        obj = {};
        for (j = 0; j < columns.length; j++) {
            obj[ columns[j] ] = data[i][j];
        }
        objects.push(obj);
    }
    return objects;
}


array.forEach(
    _table2objects([
   [
      "name",
      "type",
      "validateSpec"
   ],
   [
      "account_id",
      "i32",
      [
         {
            "high" : "10000",
            "low" : "1",
            "type" : "range"
         }
      ]
   ],
   [
      "password",
      "string",
      [
         {
            "pattern" : "^[^ ]+$",
            "type" : "regex"
         }
      ]
   ],
   [
      "username",
      "string",
      [
         {
            "high" : "8",
            "low" : "1",
            "type" : "length"
         }
      ]
   ]
]
),
    function (type, i) {
        dojo.declare('Tappy.' + type.name, Tapir.Type.Custom, type);
    }
);

// Custom Enum


// Custom exceptions and structures

dojo.declare('Tappy.account', Tapir.Type.Struct, {
    fieldSpec: _table2objects([
   [
      "index",
      "name",
      "optional",
      "type",
      "validateSpec"
   ],
   [
      "1",
      "id",
      false,
      "Tappy.account_id",
      []
   ],
   [
      "2",
      "allocation",
      false,
      "i32",
      []
   ],
   [
      "3",
      "is_admin",
      true,
      "bool",
      []
   ]
]
)
});
dojo.declare('Tappy.genericCode', Tapir.Type.Exception, {
    fieldSpec: _table2objects([
   [
      "index",
      "name",
      "optional",
      "type",
      "validateSpec"
   ],
   [
      "1",
      "code",
      false,
      "i16",
      []
   ],
   [
      "2",
      "message",
      false,
      "string",
      []
   ]
]
)
});
dojo.declare('Tappy.insufficientResources', Tapir.Type.Exception, {
    fieldSpec: _table2objects([
   [
      "index",
      "name",
      "optional",
      "type",
      "validateSpec"
   ],
   [
      "1",
      "code",
      false,
      "i16",
      []
   ],
   [
      "2",
      "message",
      false,
      "string",
      []
   ]
]
)
});

// Services

dojo.declare('Tappy.Accounts', Tapir.Service, {
    name: 'Accounts',
    methods: [ "createAccount", "getAccount" ],
    baseName: 'Tappy.Accounts'
});

TapirClient.services.push('Tappy.Accounts');

array.forEach(
    _table2objects([
   [
      "name",
      "serviceName",
      "fieldSpec",
      "spec"
   ],
   [
      "createAccount",
      "Accounts",
      [
         [
            "1",
            "username",
            false,
            "Tappy.username",
            []
         ],
         [
            "2",
            "password",
            false,
            "Tappy.password",
            [
               {
                  "high" : null,
                  "low" : "1",
                  "type" : "length"
               }
            ]
         ],
         [
            "3",
            "is_admin",
            true,
            "bool",
            []
         ]
      ],
      {
         "exceptions" : [
            [
               "1",
               "insufficient",
               false,
               "Tappy.insufficientResources",
               []
            ],
            [
               "2",
               "code",
               false,
               "Tappy.genericCode",
               []
            ]
         ],
         "returns" : "Tappy.account"
      }
   ],
   [
      "getAccount",
      "Accounts",
      [
         [
            "1",
            "username",
            false,
            "Tappy.username",
            []
         ]
      ],
      {
         "exceptions" : [
            [
               "1",
               "code",
               false,
               "Tappy.genericCode",
               []
            ]
         ],
         "returns" : "Tappy.account"
      }
   ]
]
),

    function (method, i) {
        method.fieldSpec       = _table2objects(method.fieldSpec, fieldHeader);
        method.spec.exceptions = _table2objects(method.spec.exceptions, fieldHeader);
        dojo.declare('Tappy.' + method.serviceName + '.' + method.name, Tapir.Method, method);
    }
);

});



