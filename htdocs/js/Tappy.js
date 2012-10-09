(function () {

var _methods, i, fieldHeader = ['index', 'name', 'optional', 'type', 'validateSpec'], _types_custom;

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


_types_custom = _table2objects([
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
);
for (i = 0; i < _types_custom.length; i++) {
    dojo.declare('Tappy.' + _types_custom[i].name, Tapir.Type.Custom, _types_custom[i]);
}

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
      "account_id",
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

_methods = _table2objects([
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
            "username",
            []
         ],
         [
            "2",
            "password",
            false,
            "password",
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
               "insufficientResources",
               []
            ],
            [
               "2",
               "code",
               false,
               "genericCode",
               []
            ]
         ],
         "returns" : "account"
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
            "username",
            []
         ]
      ],
      {
         "exceptions" : [
            [
               "1",
               "code",
               false,
               "genericCode",
               []
            ]
         ],
         "returns" : "account"
      }
   ]
]
);
for (i = 0; i < _methods.length; i++) {
    _methods[i].fieldSpec       = _table2objects(_methods[i].fieldSpec, fieldHeader);
    _methods[i].spec.exceptions = _table2objects(_methods[i].spec.exceptions, fieldHeader);
    dojo.declare('Tappy.' + _methods[i].serviceName + '.' + _methods[i].name, Tapir.Method, _methods[i]);
}

})();



