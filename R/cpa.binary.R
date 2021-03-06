#' Analytic power calculations for parallel arm cluster-randomized trials with binary outcomes
#'
#' @description 
#' \loadmathjax
#' 
#' Compute the power, number of clusters needed, number of subjects per cluster needed, 
#' or other key parameters for a parallel cluster randomized trial with a 
#' binary outcome.
#'
#' Exactly one of \code{alpha}, \code{power}, \code{nclusters}, \code{nsubjects},
#'   \code{CV}, \code{p1}, \code{p2}, and \code{ICC} must be passed as \code{NA}.
#'   Note that \code{alpha}, \code{power}, and \code{CV} have non-\code{NA}
#'   defaults, so if those are the parameters of interest they must be
#'   explicitly passed as \code{NA}.
#'
#'
#'
#' @section Authors:
#' Jonathan Moyer (\email{jon.moyer@@gmail.com}), Ken Kleinman (\email{ken.kleinman@@gmail.com})
#' 
#' @section Notes:
#' 
#' 
#' This function implements the approach of Donner and Klar (2000). An estimate for the
#'  intracluster correlation coefficient (ICC) is used to calculate a design effect that 
#'  accounts for variance inflation due to clustering. 
#'  
#'  There are several ways in
#'  which estimates for the ICC for a binary outcome can be calculated, as described by
#'  Wu, Crespi, and Wong (2012). The
#'  user is advised to exercise caution in estimating, generating, and interpreting ICCs in
#'  this setting.
#' 
#'  Unlike in the case of normal distributed outcomes (cpa.normal), the ICC refers neither to 
#'  any natural parameter of a data generating model nor to any function of its parameters.   
#'  For this reason we do not offer the user a option to input
#'  the variance between the clusters.  If you prefer to use that input, we suggest using the
#'  cps.binary function.
#' 
#'   This function was inspired by work from Stephane Champely (pwr.t.test) and
#'   Peter Dalgaard (power.t.test). As with those functions, 'uniroot' is used to
#'   solve power equation for unknowns, so you may see
#'   errors from it, notably about inability to bracket the root when
#'   invalid arguments are given.  This generally means that no solution exists for which the 
#'   omitted parameter and the supplied parameters fulfill the equation.  In particular, the desired
#'   power may not be achievable with any number of subjects or clusters.
#'   
#' @section Testing details:
#' This function has been verified against reference values from the NIH's GRT
#' Sample Size Calculator, PASS11, \code{CRTSize::n4props}, 
#' and \code{clusterPower::cps.binary}.
#'   
#' @param alpha The level of significance of the test, the probability of a
#'   Type I error.
#' @param power The power of the test, 1 minus the probability of a Type II
#'   error.
#' @param nclusters The number of clusters per condition. It must be greater than 1.
#' @param nsubjects The mean of the cluster sizes.
#' @param CV The coefficient of variation of the cluster sizes. When \code{CV} = 0,
#'   (default) the clusters all have the same size.
#' @param p1 The proportion with the outcome in one of the conditions, a numeric between 0-1.
#' @param p2 The proportion with the outcome in the other condition, a numeric between 0-1.
#' @param ICC The intraclass correlation, a numeric between 0-1.  (See Details, below.)
#' @param pooled Logical indicating if pooled standard error should be used.
#' @param p1inc Logical indicating if p1 is expected to be greater than p2.  
#' Only needed if \code{p1} or \code{p2} is \code{NA}.
#' @param tol Numerical tolerance used in root finding. The default provides
#'   at least four significant digits.
#' @param tdist If \code{TRUE} use t distribution with df equal to (nclusters - 2).  
#' Otherwise use the normal distribution. Default is TRUE.
#'   
#' @return
#' The computed value of the NA parameter (among \code{alpha}, \code{power}, 
#'   \code{nclusters}, \code{nsubjects},
#'   \code{CV}, \code{p1}, \code{p2}, and \code{ICC}) needed to satisfy the power and 
#'   sample size equation.
#'
#' @examples 
#' # Find the number of clusters per condition needed for a trial with alpha = .05, 
#' # power = 0.8, 10 observations per cluster, no variation in cluster size, probability
#' # in condition 1 of .1 and condition 2 of .2, and ICC = 0.1.
#' \dontrun{
#' cpa.binary(power = 0.08, nsubjects = 10, p1 = 0.1, p2 = 0.2, ICC = 0.1)
#' }
#' # 
#' # The result, showing nclusters of greater than 37, suggests 38 clusters per 
#' # condition should be used.
#' 
#' # Find the minimum detectable p2 > p1, given 38 clusters per condition, 10 
#' # observations per cluster no variation in cluster size, ICC of 0.1, and 
#' # probability of .1 in condition 2, with power of .8.
#' \dontrun{
#' cpa.binary(power = 0.08, nsubjects = 10, nclusters = 38,
#'   p1 = 0.1, p2 = NA, ICC = 0.1, p1inc = FALSE)
#' }
#' # The result shows that p2 greater than 0.198922 can be detected with at 
#' # least 80% power.
#' 
#' @references Donner A, Klar N. Design and Analysis of Cluster Randomization
#' Trials in Health Research. London; Arnold; 2000.
#' @references Wu S, Crespi CM, Wong WK. Comparison of Methods for Estimating Intraclass
#' Correlation Coefficient for Binary Responses in Cancer Prevention Cluster Randomized
#' Trials. Contemp Clin Trials. 2012; 33(5): 869-880. doi:10.1016/j.cct.2012.05.004 
#' London: Arnold; 2000.
#' @export



cpa.binary <- function(alpha = 0.05,
                       power = NA,
                       nclusters = NA,
                       nsubjects = NA,
                       CV = 0,
                       p1 = NA,
                       p2 = NA,
                       ICC = 0.05,
                       pooled = FALSE,
                       p1inc = TRUE,
                       tdist = TRUE,
                       tol = .Machine$double.eps ^ 0.25) {
  if (!is.na(nclusters) && nclusters <= 1) {
    stop("'nclusters' must be greater than 1.")
  }
  
  needlist <-
    list(alpha, power, nclusters, nsubjects, CV, p1, p2, ICC)
  neednames <-
    c("alpha",
      "power",
      "nclusters",
      "nsubjects",
      "CV",
      "p1",
      "p2",
      "ICC")
  needind <- which(unlist(lapply(needlist, is.na))) # find NA index
  
  if (length(needind) != 1) {
    stop(
      "Exactly one of 'alpha', 'power', 'nclusters', 'nsubjects', 'CV', 'p1', 'p2', or 'ICC' must be NA."
    )
  }
  
  target <- neednames[needind]
  
  pwr <- quote({
    DEFF <- 1 + ((CV ^ 2 + 1) * nsubjects - 1) * ICC
    if (pooled) {
      p <- (p1 + p2) / 2
      sdd <- sqrt(p * (1 - p) * 2 * DEFF / (nclusters * nsubjects))
    } else {
      sdd <-
        sqrt((p1 * (1 - p1) + p2 * (1 - p2)) * DEFF / (nclusters * nsubjects))
    }
    if (tdist == FALSE) {
      zcrit <- qnorm(alpha / 2, lower.tail = FALSE)
      pnorm(abs(p1 - p2) / sdd - zcrit, lower.tail = TRUE)
    } else {
      tcrit <- qt(alpha / 2, 2 * (nclusters - 1), lower.tail = FALSE)
      ncp <- abs(p1 - p2) / sdd
      pt(tcrit, 2 * (nclusters - 1), ncp, lower.tail = FALSE)
    }
  })
  
  # calculate alpha
  if (is.na(alpha)) {
    alpha <- stats::uniroot(function(alpha)
      eval(pwr) - power,
      interval = c(1e-10, 1 - 1e-10),
      tol = tol)$root
  }
  
  # calculate power
  if (is.na(power)) {
    power <- eval(pwr)
  }
  
  # calculate nclusters
  if (is.na(nclusters)) {
    nclusters <- stats::uniroot(function(nclusters)
      eval(pwr) - power,
      interval = c(2 + 1e-10, 1e+07),
      tol = tol)$root
  }
  
  # calculate p1
  if (is.na(p1)) {
    if (p1inc) {
      p1 <- stats::uniroot(
        function(p1)
          eval(pwr) - power,
        interval = c(p2 + 1e-7, 1 - 1e-7),
        tol = tol
      )$root
    } else {
      p1 <- stats::uniroot(
        function(p1)
          eval(pwr) - power,
        interval = c(1e-7, p2 - 1e-7),
        tol = tol
      )$root
    }
  }
  
  # calculate p2
  if (is.na(p2)) {
    if (p1inc) {
      p2 <- stats::uniroot(
        function(p2)
          eval(pwr) - power,
        interval = c(1e-7, p1 - 1e-7),
        tol = tol
      )$root
      
    } else {
      p2 <- stats::uniroot(
        function(p2)
          eval(pwr) - power,
        interval = c(p1 + 1e-7, 1 - 1e-7),
        tol = tol
      )$root
    }
  }
  
  # calculate nsubjects
  if (is.na(nsubjects)) {
    nsubjects <- stats::uniroot(
      function(nsubjects)
        eval(pwr) - power,
      interval = c(2 + 1e-10, 1e+07),
      tol = tol,
      extendInt = "upX"
    )$root
  }
  
  # calculate CV
  if (is.na(CV)) {
    CV <- stats::uniroot(
      function(CV)
        eval(pwr) - power,
      interval = c(1e-7, 1e+07),
      tol = tol,
      extendInt = "downX"
    )$root
  }
  
  # calculate ICC
  if (is.na(ICC)) {
    ICC <- stats::uniroot(function(ICC)
      eval(pwr) - power,
      interval = c(1e-07, 1 - 1e-7),
      tol = tol)$root
  }
  
  structure(get(target), names = target)
}
