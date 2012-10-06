namespace perl Tappy

// @validate range 1-10000
typedef i32 account_id

// @validate length 1-8
typedef string username

typedef string password

/*
	A structure representing an account
*/
struct account {
	1: account_id id,
	2: i32        allocation
}

exception insufficientResources {
	1: i16    code,
	2: string message
}

exception genericCode {
	1: i16    code,
	2: string message
}

/*
	The accounts service provides various methods to create new accounts
*/
service Accounts {
	/*
		Create a new account

		(start code)
		post {
			username: "franklin",
			password: "secretsauce"
		}
		returns {
			id: 12345,
			allocation: 94
		}
		(end)

		@rest POST /accounts
	*/
	account createAccount (
		1: username username, // The username
		2: string   password  // The account password @validate length 1-
	)
	throws (
		1: insufficientResources insufficient,
		2: genericCode code
	),

	/*
		Get an account by username
		@rest GET /account/:username
	*/
	account getAccount (
		1: username username
	)
	throws (
		1: genericCode code
	)
}
