" Vim syntax file
" Language:     mbsync setup files
" Maintainer:   zsugabubus
" Last Change:  2019-12-04
" Licence:      WTFPL

if exists('b:current_syntax')
	finish
endif

syntax match mbsyncSynError /.\+$/ keepend

syntax match mbsyncOption /\v^\s*<%(Path|MapInbox|Trash|Inbox|Tunnel|AuthMechs|CertificateFile|ClientCertificate|ClientKey|DisableExtension|IMAPStore|Account|PathDelimiter|Channel|Pattern|SyncState|FieldDelimiter)>/ skipwhite nextgroup=mbsyncString
syntax match mbsyncOption /\v^\s*<%(DisableExtensions|Patterns|Group|Channels)>/ skipwhite nextgroup=mbsyncMoreString
syntax match mbsyncOption /\v^\s*<%(MaxSize|BufferLimit)>/ skipwhite nextgroup=mbsyncSize
syntax match mbsyncOption /\v^\s*<%(Far|Near)>/ skipwhite nextgroup=mbsyncStore
syntax match mbsyncOption /\v^\s*<%(Create|Remove|Expunge)>/ skipwhite nextgroup=mbsyncFarNear
syntax match mbsyncOption /\v^\s*<%(Port|Timeout|PipelineDepth|MaxMessages)>/ skipwhite nextgroup=mbsyncNumber
syntax match mbsyncOption /\v^\s*<%(Flatten|MaildirStore|InfoDelimiter|IMAPAccount|Host|User|Pass)>/ skipwhite nextgroup=mbsyncString
syntax match mbsyncOption /\v^\s*<%(SubFolders)>/ skipwhite nextgroup=mbsyncSubFolders
syntax match mbsyncOption /\v^\s*<%(SSLType)>/ skipwhite nextgroup=mbsyncSSLType
syntax match mbsyncOption /\v^\s*<%(Sync)>/ skipwhite nextgroup=mbsyncSync
syntax match mbsyncOption /\v^\s*<%(SSLVersions)>/ skipwhite nextgroup=mbsyncSSLVersions
syntax match mbsyncOption /\v^\s*<%(PassCmd)>/ skipwhite nextgroup=mbsyncPlusString,mbsyncString
syntax match mbsyncOption /\v^\s*<%(TrashNewOnly|TrashRemoteNew|AltMap|SystemCertificates|UseNamespace|ExpireUnread|CopyArrivalDate|FSync)>/ skipwhite nextgroup=mbsyncYesNo

syntax match  mbsyncNumber       contained /\v<\d+>/
syntax match  mbsyncSize         contained /\c\v<\d+[km]?b?>/
syntax match  mbsyncStore        contained /:[^-].\{-}:[^-]*/
syntax match  mbsyncString       contained /["']\@!\S\+/
syntax region mbsyncString       contained oneline start=/"/ end=/"/
syntax region mbsyncString       contained oneline start=/'/ end=/'/
syntax match  mbsyncMoreString   contained /["']\@!\S\+/ skipwhite nextgroup=mbsyncMoreString
syntax region mbsyncMoreString   contained oneline start=/"/ end=/"/ skipwhite nextgroup=mbsyncMoreString
syntax region mbsyncMoreString   contained oneline start=/'/ end=/'/ skipwhite nextgroup=mbsyncMoreString
syntax match  mbsyncYesNo        contained /\v<%(yes|no)>/
syntax match  mbsyncSubFolders   contained /\v<%(Verbatim|Maildir\+\+|Legacy)>/
syntax match  mbsyncSSLType      contained /\v<%(None|STARTTLS|IMAPS)>/
syntax match  mbsyncSSLVersions  contained /\v<%(SSLv3|TLSv1(|.1|.2))>/
syntax match  mbsyncSync         contained /\v<%(Pull|Push)?(New|ReNew|Delete|Flags)?>/ skipwhite nextgroup=mbsyncSync
syntax match  mbsyncSync         contained /\v<(None|All)>/
syntax match  mbsyncFarNear      contained /\v<(None|Far|Near|Both)>/
syntax match  mbsyncPlusString   contained "+" nextgroup=mbsyncString

syntax region mbsyncComment start=/^#/ end='$' contains=@Spell oneline keepend

hi def link mbsyncComment      Comment
hi def link mbsyncCommentError Error
hi def link mbsyncFarNear      Identifier
hi def link mbsyncMoreString   String
hi def link mbsyncNumber       Number
hi def link mbsyncOption       Type
hi def link mbsyncSize         Number
hi def link mbsyncSSLType      Identifier
hi def link mbsyncSSLVersions  Identifier
hi def link mbsyncStore        Identifier
hi def link mbsyncString       String
hi def link mbsyncSubFolders   Identifier
hi def link mbsyncSync         Identifier
hi def link mbsyncSynError     Error
hi def link mbsyncYesNo        Boolean

let b:current_syntax = 'mbsyncrc'
