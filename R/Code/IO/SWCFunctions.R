# SWCFunctions.R
# #################################
# This file contains functions for reading in Neurons 
# in SWC format.  These have been superseded by functions
# in ReadNeuronFromAsc which read Neurolucida .asc files
# directly.  It also includes the rather hideous re-root
# function which sets the root of a neuron to a new point
# This also is no longer required when reading directly from
# Neurolucida files.
# #################################

#RELEASE
#BEGINCOPYRIGHT
###############
# R Source Code to accompany the manuscript
#
# "Comprehensive Maps of Drosophila Higher Olfactory Centers: 
# Spatially Segregated Fruit and Pheromone Representation"
# Cell (2007), doi:10.1016/j.cell.2007.01.040
# by Gregory S.X.E. Jefferis*, Christopher J. Potter*
# Alexander M. Chan, Elizabeth C. Marin
# Torsten Rohlfing, Calvin R. Maurer, Jr., and Liqun Luo
#
# Copyright (C) 2007 Gregory Jefferis <gsxej2@cam.ac.uk>
# 
# See flybrain.stanford.edu for further details
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#################
#ENDMAINCOPYRIGHT

# source(file.path(CodeDir,"SWCFunctions.R"))

# A typical use would be:
# MyNeuron<-SWC2Neuron(ReadSWCFile("A:File:Path:JL2R.swc"),"JL2R")
# plotneuron2d(MyNeuron,ToFile=T) # produce a rotater file

ReadNeuronFromSWC<-function(f, ...){
  .Deprecated('nat::read.neuron')
  nat::read.neuron(f, format='swc', ...)
}

# ReadSWCFile reads in an SWC format file
# returning an array containing all the data points
ReadSWCFile<-function(FileName,...){  
	# According to http://www.soton.ac.uk/~dales/morpho/morpho_doc/
	# SWC file format has a radius not a diameter specification
	ColumnNames<-c("PointNo","Label","X","Y","Z","W","Parent")
		d=read.table(FileName, header = FALSE, sep = "", quote = "\"'", dec = ".",
		 col.names=ColumnNames, check.names = TRUE, fill = FALSE,
		strip.white = TRUE, blank.lines.skip = TRUE,comment.char = "#",...)
	# ... so multiply by 2 to get diam which is what I work with internally
	d$W=d$W*2
	d
}

#' Convert SWC style definition of a neuron into complete neuron object
#'
#' As of 2013-10-25 SWC2Neuron uses CoreNeuronFromSWC as the parser to generate
#' seglist etc. This produces a seglist starting at the root and proceeding
#' in a depth first search through the other nodes. The old method ParseSWC
#' does not start from the root node, and therefore produces SegLists that
#' finish at the root node.
#' @param swc Matrix or data.frame with swc style definition of neuron
#' @param filename Path to the original file 
#' @param parse.method See details
#' @return List with class neuron
#' @export
#' @seealso \code{\link{is.neuron}},\code{\link{read.neuron}}, \code{\link{ReadNeuronFromSWC}}, \code{\link{ParseSWC}}
#' @examples
SWC2Neuron<-function(swc,filename,parse.method=c("CoreNeuronFromSWC","ParseSWC")){
	parse.method=match.arg(parse.method)
	neuron_core=match.fun(parse.method)(data.frame(swc))
	neuron_extra=list(NeuronName=NeuronNameFromFileName(filename),
		InputFileName=filename,
		CreatedAt=Sys.time(),
		NodeName=Sys.info()["nodename"],
		InputFileStat=file.info(filename)[1,])
	as.neuron(c(neuron_extra,neuron_core))
}

WriteSWCFile<-function(ANeuron,FileName, ...){
  .Deprecated('nat::write.neuron')
  nat::write.neuron(ANeuron, FileName, format='swc', ...)
}

# this is a utility function to find all the points neighbouring
# a given point.  Bi and Trifurcations are permitted, but no more.
findneighbours<-function(MyNeuron){
    #Set up the 2D array #nb maxneighbours=5
    Neighbours<-array(0,dim=c(MyNeuron$NumPoints,5))
    
    for(i in 1:MyNeuron$NumPoints){
	TheseNeighbours<-c(MyNeuron$d[i,"Parent"],
	    MyNeuron$d[MyNeuron$d$Parent==i,"PointNo"])
	Neighbours[i,]<-c(TheseNeighbours,rep(0,5-length(TheseNeighbours)))
    }
    #print(Neighbours)
    #Check one thing - is there a -1 in the root's row
    if(!any(Neighbours[MyNeuron$StartPoint,]==-1)){
	# OK need to insert that -1
	# Just to be good, check that there aren't too many points in this row
	if(length(which(Neighbours[MyNeuron$StartPoint,]!=0))>4){
	    print(Neighbours[MyNeuron$StartPoint,])
	    stop("Too many branches at StartPoint in findneighbours")
	}
	
	Neighbours[MyNeuron$StartPoint,]<-c(-1,Neighbours[MyNeuron$StartPoint,][1:4])
    }
    #print("Got to end of findneighbours")
    return(Neighbours)
}
                                                                # 
#------------------------------------------------------------------------#
# reroot a tree on a given Point Number
# recalculating the segment list
reroot<-function(MyNeuron,NewRoot){
    Ns<-findneighbours(MyNeuron)
    Ns[MyNeuron$StartPoint,]<-c(Ns[MyNeuron$StartPoint,-1],0)
    Ns[NewRoot,]<-c(-1,Ns[NewRoot,1:4])
    
    lut<-table(Ns)[-(1:2)]
    NsToFind<-lut[as.character(1:MyNeuron$NumPoints)]
    # # Default type is 0
    PointType<-rep(0,MyNeuron$NumPoints)
    # Points with only 1 neighbour are ends (type 2)
    EndPoints<-which(Ns[,2]==0)
    PointType[EndPoints]<-2
    # Points with at least 3 neighbours are branchpoints
    BranchPoints<-which(Ns[,3]!=0)
    PointType[BranchPoints]<-1
    # The root point type does need special handling.
    StartType<-PointType[NewRoot]
    # If it's not a branch point, then it must be an end point
    if(StartType!=1){
	EndPoints<-sort(c(EndPoints,NewRoot))
	PointType[NewRoot]<-2
    }
    
    
    
    # Decided I wanted to leave the root with its normal type
    ##PointType[NewRoot]<- (-1)
    
    #OK This is going to be a big loop!
    #General principle is: Imagine an ant walks along the
    #tree starting at the root.  Every step it figures
    # out what kind of point it's on and what it
    # has to do next.  The ant has finished when it has visited
    # every endpoint on the tree
    #Functions to be filled in

      #################### START OF ANT FUNCTIONS ##################
                                                              # 
    InitialiseAnt<-function(Ant){
	Ant$EndsVisited<-0       #1
	Ant$CurrSeg<-0         #2
	Ant$PointInSeg<-0   #3
	Ant$LastBranch<-NULL  #4
	Ant$BranchStackSize<-0  #5 
	Ant$CurrPoint<-NewRoot  #6
	Ant$LastPoint<-(-1)  #7
	Ant$IsSegOpen<-F  #8
	Ant$EndsToVisit<-length(EndPoints)  #9
	Ant$Ops<-0  #10
	Ant$SegList<-list()  #11
	Ant$NsToVisit<-Ns  #12
	return(Ant)
    }
    # INITIALISE THE ANT
    Ant<-list()
    Ant<-InitialiseAnt(Ant)
    # The ant is used as follows
    # Ant<-FntoChangeAntStatus(Ant)
    # OR
    # if(FntoCheckAntStatus())
    
    # For debugging:
    #print (Ant[1:10])

    
    IsBranchPoint<-function(Ant){
	if((Ant$CurrPoint>MyNeuron$NumPoints) | (Ant$CurrPoint<1)){
	    stop("CurrPoint out of bounds in IsBranchPoint")
	}
	
    return(PointType[Ant$CurrPoint]==1)
    }

    IsEndPoint<-function(){
    return(PointType[Ant$CurrPoint]==2)
    }

    TerminateSeg<-function(Ant){
	#remember to remove points from list
	Ant<-RemovePointFromList(Ant$CurrPoint,Ant$LastPoint,Ant)
	Ant<-RemovePointFromList(Ant$LastPoint,Ant$CurrPoint,Ant)
	Ant$IsSegOpen<-F
	return(Ant)
    }
    
    
    PickNextNeighbour<-function(){
	PossNeighbours<-Ant$NsToVisit[Ant$CurrPoint,]
	#print(PossNeighbours)
	#Reject any -1s or 0s
	PossNeighbours<-PossNeighbours[PossNeighbours>0]
	#Return first value in the list or -1 if none
	rval<-c( PossNeighbours,-1)[1]
	if(rval<1 & !IsBranchPoint(Ant)){
	    print(Ant$CurrPoint)
	    print(Ant$NsToVisit[Ant$CurrPoint,])
	    stop("Got to a non branch point with no neighbours in PickNextNeighbour")
	}
	
	#print(PossNeighbours)
		
	return(rval)
    }

    PointHasNeighbours<-function(){
	return(PickNextNeighbour()>0)
    }

    RemovePointFromList<-function(WhichList,WhichPoint,Ant){
	
	# Should prob die if WhichList is too big
	if(WhichList>MyNeuron$NumPoints){
	    stop("Tried to access a point outside the Neighbour List in RemovePointFromList")
	}
	
	# Just in case I try to pass a -1 value (which I don't mind ignoring)
	if(WhichList>0){
	    ThisRow<-Ant$NsToVisit[WhichList,]
	    Ant$NsToVisit[WhichList,which(ThisRow==WhichPoint)]<-0
	}
    
	
	return(Ant)
    }
    
    
    IsStackEmpty<-function() return(Ant$BranchStackSize<1)
    
    PopBranchPointOntoStackIfReqd<-function(Ant){
	if(!IsBranchPoint(Ant)){
	 # Return an error if we aren't at a branch point
	    stop("PopBranchPointOntoStackIfReqd called outside branch point")
	}
	
	#print("called PopBranchPointOntoStackIfReqd")
	#print(Ant$LastBranch)
	if(IsStackEmpty()){
	    #Add the current branch point to the top of the stack
	    Ant$BranchStackSize<-Ant$BranchStackSize+1
	    Ant$LastBranch[Ant$BranchStackSize]<-Ant$CurrPoint
	    return(Ant)
	}
	if(Ant$LastBranch[Ant$BranchStackSize]!=Ant$CurrPoint){
	    #Add the current branch point to the top of the stack
	    Ant$BranchStackSize<-Ant$BranchStackSize+1
	    Ant$LastBranch[Ant$BranchStackSize]<-Ant$CurrPoint
	    return(Ant)
	}
	return(Ant)
    }

    PopBranchPointOffStack<-function(Ant){
	# Check if there's something in the stack
	# If there is, check that it's equal to the current point
	# which should be a branch point
	if(!IsStackEmpty() & Ant$LastBranch[Ant$BranchStackSize]==Ant$CurrPoint){
	    #cat("Popped off ", Ant$LastBranch[Ant$BranchStackSize])
	    Ant$LastBranch<-Ant$LastBranch[-Ant$BranchStackSize]
	    Ant$BranchStackSize<-Ant$BranchStackSize-1
	    return(Ant)
	} else {
	    print(Ant)
	    stop("Screw up in PopBranchPointOffStack")
	}
	
	
    }
    OpenSeg<-function(Ant){
	Ant$IsSegOpen<-T
	Ant$CurrSeg<-Ant$CurrSeg+1
	Ant$PointInSeg<-1
	Ant$SegList[[Ant$CurrSeg]]<-Ant$CurrPoint
	return(Ant)
    }

    #################### END OF ANT FUNCTIONS ###################
    #                                                           # 
    #  OK Ready to go now that Ant functions have been defined  # 
    #                                                           # 
    #############################################################
      
    # OK The big bad loop. Ant will keep walking until she has
    # visited every end of the neuron
    #print(EndPoints)
    while(Ant$EndsVisited<Ant$EndsToVisit){
	Ant$Ops<-Ant$Ops+1 # just a little counter to see how many steps she makes
	#For debugging
#	print(Ant)
	#cat("Num Ops=",Ant$Ops,"   CurrPoint=",Ant$CurrPoint,
	#   "  Stack=",Ant$LastBranch,"\n")
	if(IsBranchPoint(Ant) ){
	    # IT IS A BranchPoint
	    #print("Got to BranchPoint")
	    if(Ant$IsSegOpen) {
		Ant$PointInSeg<-Ant$PointInSeg+1
		Ant$SegList[[Ant$CurrSeg]][Ant$PointInSeg]<-Ant$CurrPoint
		Ant<-TerminateSeg(Ant)
	    }
	    
	    
	    if(PointHasNeighbours()){
		Ant<-PopBranchPointOntoStackIfReqd(Ant)
		Ant<-OpenSeg(Ant)
		NextPoint<-PickNextNeighbour()
		Ant$SegList[[Ant$CurrSeg]]<-Ant$CurrPoint
		RemovePointFromList(Ant$CurrPoint,NextPoint,Ant)
		Ant$LastPoint<-Ant$CurrPoint
		Ant$CurrPoint<-NextPoint
	    } else {
	        # BranchPoint has no neighbours left
		# So lets pop it off the stack ...
		Ant<-PopBranchPointOffStack(Ant)
		#Optional check
		if(Ant$CurrPoint<1 | Ant$CurrPoint>MyNeuron$NumPoints){
		    stop("Walked off the map!")
		}
		# and then retreat back to the previous branch
		Ant$CurrPoint<-Ant$LastBranch[Ant$BranchStackSize]
	    
	    } # end of if(PointHasNeighbours()) for BranchPoint
	} else { # IT ISN'T A BRANCHPOINT
	    # (Either End or Inter)
	    # Check if a segment needs to be opened
	    # Presumably this would only happen if the new root
	    # is an endpoint
	    if(!Ant$IsSegOpen) {
		Ant<-OpenSeg(Ant)
	    Ant<-RemovePointFromList(Ant$CurrPoint,Ant$LastPoint,Ant)
	    } else { # Just an ordinary point
		Ant$PointInSeg<-Ant$PointInSeg+1
		Ant$SegList[[Ant$CurrSeg]][Ant$PointInSeg]<-Ant$CurrPoint
	    Ant<-RemovePointFromList(Ant$CurrPoint,Ant$LastPoint,Ant)
	    Ant<-RemovePointFromList(Ant$LastPoint,Ant$CurrPoint,Ant)
	    }
	    
	    #Have we got to an End Point yet?
	    if(IsEndPoint()){
		# YES!  But ...
		#Now for something that caught me out!
		#Is this the StartPoint?
		if(Ant$CurrPoint==NewRoot){ 
		    #Yes, so we just want to keep going
		    #print("Figured out this a starting end point")
		    Ant$LastPoint<-Ant$CurrPoint
		    Ant$CurrPoint<-PickNextNeighbour()
		} else {
		Ant<-TerminateSeg(Ant)
		Ant$CurrPoint<-Ant$LastBranch[Ant$BranchStackSize]
		}
		#cat("Got to end ",Ant$EndsVisited," of ",Ant$EndsToVisit," to visit\n")
		Ant$EndsVisited<-Ant$EndsVisited+1
	    } else { #NOT an END
		Ant$LastPoint<-Ant$CurrPoint
		Ant$CurrPoint<-PickNextNeighbour()
		#print(Ant$CurrPoint)
	    }
		
	    
	} # end of if(IsBranchPoint()) which figures out what point we've got
	
    } # End of the monster while((Ant$EndsVisited<Ant$EndsToVisit) ... loop 
    
    #OK let's check that all points have been visited according to the neighbours
    # to visit code
    if(sum(Ant$NsToVisit)>0){
	print(apply(Ant$NsToVisit,1,sum))
	exit("Not all neighbours were visited")
    }
   
    
    #OK now overwrite MyNeuron$SegList with Ant$SegList
    MyNeuron$StartPoint<-NewRoot
    MyNeuron$BranchPoints<-BranchPoints
    MyNeuron$EndPoints<-EndPoints
    MyNeuron$NumSegs<-length(Ant$SegList)
    MyNeuron$SegList<-Ant$SegList
    
    return(MyNeuron)
} # End of Function reroot
