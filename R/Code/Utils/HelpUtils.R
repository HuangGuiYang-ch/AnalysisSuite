# Try to provide a simple online help system for functions outside of
# a package.  Idea is to extract information from roxygen comments
# in a manner similar to halp package

#' Provides help for roxygen commented functions without conventional help 
#' 
#' If regular help fails then first arg in list is checked to see if it is a
#' function that has roxygen documentation
#' @param ... args passed to regular help. 
#' @param PRINT.ARGS uses args to print function argument list
#' @param TRY.BUILTIN.HELP Check built-in help first (default TRUE)
#' @return return value of help() or invisible helptext 
#' @author jefferis
#' @seealso \code{\link{utils::help}}
#' @export
help<-function(...,PRINT.ARGS=FALSE,TRY.BUILTIN.HELP=TRUE){
	# try built in help first
	if(TRY.BUILTIN.HELP) {
  	x=utils::help(...)
  	if(length(x)>0) return(eval(x))
	}
	# if not, see if we can get somewhere with roxygen comment

	# turn off warnings for now
	ow=options('warn')
	on.exit(options(warn=ow$warn))
	options(warn=-1)

	# get source code for function
	al=try(pairlist(...),silent=TRUE)
	if(inherits(al,'try-error'))
		stop('Unable to find function')

	b=body(al[[1]])
	fun.name=as.character(substitute(...))[1]
	if(is.null(b))
		stop('No source code found for: ',fun.name)

	# we have source code, let's parse it
	srccode=as.character(attr(b,'wholeSrcref'))
	# line that finishes the function definition
	functionenddefline=as.integer(attr(b,'srcref')[[1]])[1]
	# FIXME: still sensitive to comments after function def (but on same line)
	# or to cases where function name is 
	functiondefline=max(grep("function",srccode[1:functionenddefline],fixed=T))

	if(length(functiondefline)==0 || functiondefline==1)
		stop('No help found in source code found for: ',fun.name)

	lastline=length(srccode)
	precedingline=functiondefline-1
	# reverse because we want to work backwards from function definition line
	commentlines=rev(grep("^#'",srccode[1:precedingline]))
	if(!any(commentlines==precedingline))
		# preceding line is not a comment
		stop('No help found in source code found for: ',fun.name)

	drcs=diff(commentlines)
	commentbreak=which(drcs < -1)[1]
	if(is.na(commentbreak)){
		# roxygen comment must start from first line of file
		helptext=srccode[rev(commentlines)]
	}
	else helptext=srccode[rev(commentlines[seq(commentbreak)])]
	
	# now format help text
	helptext=sub("^#[']{0,1}[ ]{0,1}","",helptext)
	helptext <- gsub("^@param (\\S+|\\.\\.\\.)"," {\\1}",helptext)
	helptext <- gsub("^@(\\w+)","[\\1]",helptext)
	if(PRINT.ARGS) {
		cat(helptext[1],"\n")
		al=deparse(args(al[[1]]))
		cat(al[-length(al)],"\n")
		cat(paste(helptext[-1],collapse="\n"))
	} else cat(paste(helptext,collapse="\n"))
	invisible(helptext)
}

#' Extend built-in help by parsing in-source roxygen comments 
#'
#' See help for details. First tries utils::?.
#' @param ... args passed to base ? or modified help functions
#' @export
#' @seealso \code{\link{help}}
`?`<-function(...){
  # first try built in help
  x=utils::`?`(...)
  if(length(x)>0) return(eval(x))

  # failing that, try checking to see if we can find 
  # and documentation in sources
  help(...,TRY.BUILTIN.HELP=FALSE)
}
