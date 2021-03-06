# Functions for matching 3d linesets / neurons
# source(file.path(DicksonRoot,"JaiScripts/NeuriteMatchingFunctions.R"))

require(RANN) # for finding nearest neighbour points
require(dtw) # for dynamic programming best matching of lines

MedianMinPointDistance<-function(n1,n2,processfun=GetLongestSegment,summaryfun=median,BothDirections=FALSE,BothDirectionsFun=mean,...){
	# this function takes 2 neurons (or 2 point lists)
	# and finds the nearest neighbours 
	if(is.null(processfun)){
		if(is.list(n1)) n1=n1$d[,c("X","Y","Z")]
		if(is.list(n2)) n2=n2$d[,c("X","Y","Z")]
	} else {
		n1=processfun(n1)
		n2=processfun(n2)		
	}
	d1=summaryfun(nn2(n1,n2,k=1,...)$nn.dists)
	if(!BothDirections) return(d1)
	d2=summaryfun(nn2(n2,n1,k=1,...)$nn.dists)
	return(BothDirectionsFun(c(d1,d2)))
}

VectorAndDistanceMatch<-function(n1,n2,processfun=GetLongestSegment,summaryfun=median,BothDirections=FALSE,BothDirectionsFun=mean,...){
	# TODO
	# this function takes 2 neurons (or 2 point lists)
	# finds the nearest neighbours for all points
	# and the vector cross products for matching points
	if(is.null(processfun)){
		if(is.list(n1)) n1=n1$d[,c("X","Y","Z")]
		if(is.list(n2)) n2=n2$d[,c("X","Y","Z")]
	} else {
		n1=processfun(n1)
		n2=processfun(n2)		
	}
	d1=summaryfun(nn2(n1,n2,k=1,...)$nn.dists)
	
	if(!BothDirections) return(d1)
	d2=summaryfun(nn2(n2,n1,k=1,...)$nn.dists)
	return(BothDirectionsFun(c(d1,d2)))
}

WeightedNNComparison<-function(a,b,normalise=FALSE,costfn=function(x) dnorm(x,sd=4),summaryfn=mean,...){
	# TODO
	# expects 2 sets of points
	# calculates a score which will be a weighted function of the distance
	# to emphasise close matches
	n<-nn2(a,b)
	mean(costfn(n$nn.dists,...))
}


BestContinuousAlignment<-function(a,b,missingCost,k=10,...){
	# use dtw package + a cost function consisting of distances for 
	# k=10 or 20 nearest neighbours and e.g. 100?s everywhere else

	# a=reference, b=query according to dtw terminology
	# use nn2 to find the nearest neighbours in b for all points of a
	abnn=nn2(b,a,k=k)
	if(missing(missingCost)) missingCost=max(abnn$nn.dists)
	dmat=matrix(missingCost,nrow=nrow(a),ncol=nrow(b))
	for (i in 1:nrow(a)){
		dmat[i,abnn$nn.idx[i,]]=abnn$nn.dists[i,]
	}
	# for dtw, x=query, y=reference
	# Element [i,j] of the local-distance matrix is understood as the distance between element x[i] and y[j]
	# The distance matrix has therefore n=length(x) rows and m=length(y) columns	
	dtw(dmat,...)
}

DtwToScore<-function(bca){
	# takes a dtw object (calculated with keep.internals=TRUE)
	# and computes a score based on the alignment indices and distances
	# the score should be additive based on the idea of 
	# the sum of the goodness of fits for each matched point 
}

CompareAllSegs<-function(n1,n2,...){
	ns1=length(n1$SegList)
	ns2=length(n2$SegList)
	d1=data.matrix(n1$d[,c("X","Y","Z")])
	d2=data.matrix(n2$d[,c("X","Y","Z")])
	smat=matrix(NA,nrow=ns1,ncol=ns2)
	l<<-list()
	for(s in 1:ns1){
		for(t in 1:ns2){
			bca<-try(BestContinuousAlignment(d1[n1$SegList[[s]],],d2[n2$SegList[[t]],],...))
			if(!inherits(bca, "try-error")){
				smat[s,t]=bca$normalizedDistance
				l[[paste(s,t)]]<<-bca				
			} else smat[s,t]=NA
		}
	}
	smat
}

NNBasedLinesetMatching<-function(n1,n2,...){
	# first find nearest neighbours in both directions

	# accept either neurons or just the point dataframes
	if(is.list(n1) & !is.data.frame(n1)) n1=data.matrix(n1$d[,c("X","Y","Z","Parent")])
	if(is.list(n2) & !is.data.frame(n2)) n2=data.matrix(n2$d[,c("X","Y","Z","Parent")])

	a=n1[,c("X","Y","Z")]
	b=n2[,c("X","Y","Z")]
	
	nnn1=nn2(a,b,k=1,...)
	#nnn2=nn2(b,a,k=1,...)
	
	idxArray=cbind(nnn1$nn.idx,seq(length(nnn1$nn.idx)))
	# Need to supply a set of pairs of points.
	# will use the parent of each chosen point.
	# if parent undefined, then ignore that point
	
	# Calculate the direction vectors
	dvs=findDirectionVectorsFromParents(n1,n2,idxArray,ReturnAllIndices=TRUE)
	if(length(attr(dvs,"badPoints"))>0) nnn1$nn.dists=nnn1$nn.dists[-attr(dvs,"badPoints")]
	# Calculate segment lengths
	l1.seglengths=normbyrow(dvs[,1:3])
	l2.seglengths=normbyrow(dvs[,4:6])
	# normalise the direction vectors
	dvs[,1:3]=dvs[,1:3]/l1.seglengths
	dvs[,4:6]=dvs[,4:6]/l2.seglengths
	# Calculate the point displacement term
	m1=l1.seglengths*(nnn1$nn.dists)^2

	# Calculate the line angle mismatch term	
	m2=l1.seglengths^3/6*(1-dotprod(dvs[,1:3],dvs[,4:6]))
	mismatch=sum(m1+m2)
	cat("sum m1:",sum(m1),"sum m2:",sum(m2),"\n")
	if(mismatch < -1e-6) {
		stop("Negative line mismatch score!")
	} else if(mismatch<0){
		mismatch=0
	}
	return(mismatch)	
}

WeightedNNBasedLinesetDistFun<-function(nndists,dotproducts,sd=3,...){
	summaryfun=function(x) 1-mean(sqrt(x),na.rm=T)
	sapply(sd,function(sd) summaryfun(dnorm(nndists,sd=sd)*dotproducts/dnorm(0,sd=sd)))
}

WeightedNNBasedLinesetDistFun.Sum<-function(nndists,dotproducts,sd=3,...){
	summaryfun=function(x) sum(sqrt(x),na.rm=T)
	sapply(sd,function(sd) summaryfun(dnorm(nndists,sd=sd)*dotproducts/dnorm(0,sd=sd)))
}

WeightedNNBasedLinesetDistFun.Score<-function(nndists,dotproducts,sd=3,threshold=2*sd,...){
	# another distance function, this time with a notion of a threshold
	# typically 2 sigma.  If you are further away than this, then you get a negative score
	# most points will have a small negative score, so the expected score is negative
	summaryfun=function(x) sum(x,na.rm=T)
	# (dnorm(seq(0,10,0.1),sd=3)-dnorm(6,sd=3))/(dnorm(0,sd=3)-dnorm(6,sd=3))
	# transformed threshold
	sdt=dnorm(threshold,sd=sd)
	sapply(sd,function(sd) summaryfun( (dnorm(nndists,sd=sd)-sdt) /(dnorm(0,sd=sd)-sdt) * dotproducts))
}

WeightedNNBasedLinesetDistFun.separate<-function(nndists,dotproducts,sd=3){
	summaryfun=function(x) 1-mean(x)
	c(summaryfun(dnorm(nndists,sd=sd)/dnorm(0,sd=sd)),summaryfun(dotproducts))
}
