---@class snacks.gh.api.Config
---@field type "issue" | "pr"
---@field repo? string
---@field fields string[]
---@field view string[] -- fields to fetch for gh view
---@field list string[] -- fields to fetch for gh list
---@field text string[]
---@field options string[]
---@field transform? fun(item: snacks.picker.gh.Item): snacks.picker.gh.Item?

---@class snacks.picker.gh.list.Config: snacks.picker.gh.Config
---@field type "issue" | "pr"

---@class snacks.picker.gh.api.Config: snacks.picker.gh.Config
---@field api snacks.gh.api.Api
---@field transform? fun(item: snacks.picker.finder.Item): snacks.picker.finder.Item?

---@alias snacks.gh.api.View snacks.picker.gh.Item|{number: number, type: string, repo: string}

---@class snacks.gh.api.Cmd
---@field args string[]
---@field repo? string
---@field input? string
---@field on_error? fun(proc: snacks.spawn.Proc, err: string)

---@class snacks.gh.api.Api
---@field endpoint string
---@field cache? string cache the response, e.g. "3600s", "1h"
---@field fields? table<string, string|number|boolean>
---@field header? table<string, string|number|boolean>
---@field jq? string
---@field input? string
---@field method? "GET" | "POST" | "PATCH" | "PUT" | "DELETE"
---@field paginate? boolean
---@field silent? boolean
---@field slurp? boolean
---@field on_error? fun(proc: snacks.spawn.Proc, err: string)

---@alias snacks.gh.Field {arg:string, prop:string, name:string}

---@class snacks.gh.cli.Action: snacks.gh.api.Cmd
---@field args? string[]
---@field stdin? boolean -- whether to write to stdin
---@field edit? string field to edit
---@field api? snacks.gh.api.Api -- api options
---@field cmd? string -- subcommand to run (e.g., "issue edit" or "pr comment")
---@field fields? snacks.gh.Field[] -- field args to parse from the body
---@field title? string -- title of the scratch buffer
---@field template? string -- template to use for the scratch buffer
---@field desc? string -- description to show in the scratch buffer
---@field icon? string -- icon to show in the scratch buffer
---@field type? "issue" | "pr" -- action for items of this type (nil means both)
---@field enabled? fun(item: snacks.picker.gh.Item): boolean -- whether the action is enabled for the item
---@field success? string -- success message to show after the action
---@field confirm? string -- confirmation message to show before performing the action
---@field refresh? boolean -- whether to refresh the item after performing the action (default: true)

---@class snacks.gh.api.Fetch: snacks.gh.api.Cmd
---@field fields string[]

---@alias snacks.gh.Reaction { content: string, users: { totalCount: number } }

---@class snacks.gh.Label
---@field id string
---@field name string
---@field color string
---@field description? string

---@class snacks.gh.User
---@field id string
---@field login string
---@field name string
---@field is_bot? boolean

---@class snacks.gh.Check
---@field __typename string
---@field completedAt? string
---@field conclusion? "SUCCESS" | "FAILURE" | "SKIPPED"
---@field detailsUrl? string
---@field name string
---@field startedAt? string
---@field status "PENDING" | "COMPLETED"
---@field workflowName string

---@class snacks.gh.Item
---@field number number
---@field id string
---@field title string
---@field labels? snacks.gh.Label[]
---@field author? snacks.gh.User
---@field state string
---@field stateReason? string
---@field updatedAt string
---@field url string
---@field reactionGroups? snacks.gh.Reaction[]
---@field body? string
---@field comments? snacks.gh.Comment[]
---@field changedFiles? number
---@field additions? number
---@field deletions? number
---@field mergeStateStatus? string
---@field mergeable? boolean
---@field commits? snacks.gh.Commit[]
---@field statusCheckRollup? snacks.gh.Check[]
---@field baseRefName? string
---@field headRefName? string
---@field isDraft? boolean

---@class snacks.gh.Commit
---@field oid string
---@field messageHeadline string
---@field messageBody? string
---@field committedDate string
---@field authors? snacks.gh.User[]
---@field authoredDate string

---@class snacks.gh.Comment
---@field id string
---@field url string
---@field author { login: string }
---@field authorAssociation? string
---@field includesCreatedEdit boolean
---@field viewerDidAuthor boolean
---@field isMinimized boolean
---@field minimizedReason string
---@field body string
---@field createdAt string
---@field reactionGroups? snacks.gh.Reaction[]

---@class snacks.picker.gh.Item: snacks.picker.Item,snacks.gh.Item,snacks.picker.finder.Item
---@field type "issue" | "pr"
---@field dirty? boolean
---@field uri string
---@field repo? string
---@field hash string
---@field status string
---@field author? string
---@field label? string
---@field status_reason? string
---@field item snacks.gh.Item
---@field body? string
---@field reactions? {content: string, count: number}[]
---@field fields table<string, boolean>
---@field created number
---@field updated number
---@field closed? number
---@field merged? number
---@field draft? boolean
