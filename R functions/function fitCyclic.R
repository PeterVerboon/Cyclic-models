#' Fits the cyclic model, using a simple linear model.

#'
#' This function fits the cyclic model, using a simple linear model (see Verboon & Leontjevas, 2018)
#' @param xvar time variabele
#' @param yvar dependent variable
#' @param P the periodicity of the cycle. If NULL the maximum of xvar will be taken.
#' @param dayNumber indicates the days, used in the plots. If NULL plot assumes only one day.
#' @param cov vector of names containing additional variabeles (e.g. cov = c("x1", "daynr"))
#' @param ymin,ymax,step parameters that control axes of the plot
#' @keywords cyclic model ESM
#' @return list containing the following elements:
#' @return parameters =      amplitude and phase
#' @return fit =             object from lm()
#' @return rawDataPlot =     plot of predicted values for all observations
#' @return meansPlot =       plot with predictions averaged over subjects,
#' @return oneCyclePlot =    plot with predictions for one cycle,
#' @import ggplot2
#' @export
#' @examples
#' fitCyclic(dat, yvar = y = "dependentVar", xvar = "beepnr", dayNumber = "daynr")
fitCyclic <- function(dat, yvar = NULL, xvar = NULL, dayNumber = NULL, cov = NULL , P = NULL, 
                      ymin = -1.0, ymax = 1.0, step=0.25 ) {  
  
    result <- list() 
    result$input <- as.list(environment())
    
    # check basic input
    if (is.null(yvar)) { stop("parameter 'yvar' has not been specified")}
    if (is.null(xvar)) { stop("parameter 'xvar' has not been specified")}

    if (!is.null(yvar))  { if (!yvar %in% colnames(dat)) { stop(paste0("Variable '", yvar, "' does not exist"))}}
    if (!is.null(xvar))  { if (!xvar %in% colnames(dat)) { stop(paste0("Variable '", xvar, "' does not exist"))}}
    
    if (is.null(cov)) a.cov <- NULL
    
    ifelse (is.null(cov),form <- paste0("y ~ cvar + svar"), form <- paste0("y ~ cvar + svar + ", cov) )

    if (is.null(P)) {P <- max(dat[,xvar])}
    
    dat$cvar <- cos((2*pi/P)*dat[,xvar])
    dat$svar <- sin((2*pi/P)*dat[,xvar])
    dat$y <- dat[,yvar]
    dat$x <- dat[,xvar]
    ifelse (is.null(dayNumber), dat$day <- "single day"  , dat$day <- as.factor(dat[,dayNumber]))

    
    # fit cyclic model within days across beeps
    
    fitp <- lm(form, data=dat)

    a0 <- fitp$coefficients[1]
    a1 <- fitp$coefficients[2]
    a2 <- fitp$coefficients[3] 
   
    if(!is.null(cov)) { a.cov <- fitp$coefficients[4:(3+length(cov))]} 
    
    par <- cycpar(a1,a2, P) 

    b <- c(a0,par)
    
    # Parameters b1 and b2 are obtained from cyclic model analysis
    
    b1 <- b[2]
    b2 <- b[3] 
    
    if (!is.null(cov))  { 
       ypred1 <-  a0 + b1*cos(2*pi/P*(dat$x - b2)) +  as.matrix(dat[,cov]) %*% a.cov 
       } else { ypred1 <-  a0 + b1*cos(2*pi/P*(dat$x - b2)) }
      
    npoints <- dim(dat)[1]
    dat$xall <- c(1:npoints)
    
    # raw data plot
    
    g0 <- ggplot(dat) + geom_point(aes(x=xall, y=dat$y, colour=dat$day))
    g0 <- g0 + scale_x_discrete(name ="Time points (beeps within days)",  labels=dat$x, limits=c(1:npoints))
    g0 <- g0 + labs(y = yvar)
    g0 <- g0 + theme(axis.text = element_text(size = 6, colour="black"),legend.position="none")
    g0 <- g0 + geom_line(aes(x=dat$xall, y=ypred1)) 
    g0 <- g0 + coord_cartesian(ylim=c(ymin, ymax)) + scale_y_continuous(breaks=seq(ymin, ymax, step)) 
    
    
    # one Cycle plot 
    
    g <- ggplot(dat)  + geom_point(aes(x=dat$x,y=dat$y))
    g <- g + geom_hline(yintercept=a0, colour="blue")  
    g <- g + geom_vline(xintercept=b2, colour="red") 
    g <- g + geom_line(aes(x=dat$x, y=ypred1)) 
    g <- g + labs(x = "Time points", y = yvar)
    g <- g + scale_x_discrete(name ="Time points",  limits=c(1:P))
    g <- g + coord_cartesian(ylim=c(ymin, ymax)) + scale_y_continuous(breaks=seq(ymin, ymax, step)) 
    g <- g + theme(axis.text = element_text(size = 12, colour="black"))
 
    
    # mean plot
    
      pdat2 <- aggregate(dat[,c(yvar,cov)],by=list(dat[,xvar]), FUN=mean, na.rm=F)   
      pdat2$y <- pdat2[,2]
      pdat2$x <- pdat2[,1]
     
    if (!is.null(cov))  { 
       ypred2 <-  a0 + b1*cos(2*pi/P*(pdat2$x - b2)) +  as.matrix(pdat2[,cov]) %*% a.cov 
       } else { ypred2 <-  a0 + b1*cos(2*pi/P*(pdat2$x - b2)) }
    
    g1 <- ggplot(pdat2) + geom_point(aes(x=pdat2$x,y=pdat2$y))
    g1 <- g1 + geom_hline(yintercept=a0, colour="blue")
    g1 <- g1 + geom_vline(xintercept=b2, colour="red")
    g1 <- g1 + geom_line(aes(x=pdat2$x, y=ypred2))
    g1 <- g1 + labs(x = "Time points", y = yvar)
    g1 <- g1 + scale_x_discrete(name ="Time points",  limits=c(1:P))
    g1 <- g1 + coord_cartesian(ylim=c(ymin, ymax)) + scale_y_continuous(breaks=seq(ymin, ymax, step)) 
    g1 <- g1 + theme(axis.text = element_text(size = 12, colour="black"))

    
    result$meansPlot <- g1
    result$rawDataPlot <- g0
    result$oneCyclePlot <- g
    result$fit  <- fitp
    result$parameters <- b
    result$formula <- form
    result$period <- P
    result$predictions <- list(raw = ypred1, mean = ypred2)
    
    class(result) <- "fitCyclic"
    return(result)

}     



#'
#' Plots fitCyclic object
#' @param plotType one or more elements of "raw","means","oneCycle"
#' @method plot fitCyclic
#' @import ggplot2
#' @export
plot.fitCyclic <- function(x, plotType = c("raw","means","oneCycle")) {
  
  if("raw" %in% plotType) plot(x$rawDataPlot) 
  if("means" %in% plotType) plot(x$meansPlot) 
  if("oneCycle" %in% plotType) plot( x$oneCyclePlot) 
 
}




#'
#' Prints fitCyclic object
#' @method print fitCyclic
#' @export
print.fitCyclic <- function(x,digits=2,...) {
  
  b <- data.frame(x$parameters)
  colnames(b) <- "estimates"
  
  cat("The dependent variable is:   ",x$input$yvar, "\n", sep="")
  cat("The time variable is:        ",x$input$xvar, "\n", sep="")
  if (!is.null(x$input$cov)) cat("The covariates are:        ",x$input$cov, "\n", sep="  ")
  cat("\n")
  cat("The period of the cycle is: ", x$period ,"\n")
  cat("The formula used to fit the model is:   ",x$formula, "\n\n")
  cat("The cyclic parameters of the fitted model are: ", "\n\n")
  print(b, digits = digits)
  cat("\n\n")
  cat("The summary of the model fit is: ", "\n\n")
  print(summary(x$fit))
  
}






