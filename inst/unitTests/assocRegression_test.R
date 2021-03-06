library(logistf)

test_geneAction <- function() {
    set.seed(100); geno <- matrix(sample(c(0,1,2,NA), 100, replace=TRUE), nrow=10, ncol=10)
    checkEquals(geno, GWASTools:::.transformGenotype(geno, "additive"))
    
    dom <- GWASTools:::.transformGenotype(geno, "dominant")
    checkEquals(geno == 0, dom == 0)
    checkEquals(geno %in% c(1,2), dom %in% 2)
    checkEquals(is.na(geno), is.na(dom))
    
    rec <- GWASTools:::.transformGenotype(geno, "recessive")
    checkEquals(geno == 2, rec == 2)
    checkEquals(geno %in% c(1,0), rec %in% 0)
    checkEquals(is.na(geno), is.na(rec))
}

test_monomorphic <- function() {
    geno <- matrix(c(0,0,0,NA,
                     0,1,NA,2,
                     NA,2,2,2), nrow=3, byrow=TRUE)
    checkEquals(c(TRUE,FALSE,TRUE), GWASTools:::.monomorphic(geno, outcome="", model.type=""))

    ## case/control
    geno <- matrix(c(0,0,1,NA,
                     0,1,1,2,
                     NA,1,2,2), nrow=3, byrow=TRUE)
    checkEquals(c(TRUE,FALSE,TRUE), GWASTools:::.monomorphic(geno, outcome=c(0,0,1,1), model.type="logistic"))
}

.regModelData <- function(type=c("logistic", "linear", "poisson"), nsamp=100) {
    type <- match.arg(type)
    data.frame(outcome=switch(type,
                   logistic={set.seed(101); rbinom(nsamp,1,0.4)},
                   linear={set.seed(102); rnorm(nsamp, mean=10, sd=2)},
                   poisson=c({set.seed(103); sample(1:20, 80, replace=TRUE)},
                             {set.seed(104); sample(21:40, 20, replace=TRUE)})),
               covar={set.seed(105); sample(letters[1:3], nsamp, replace=TRUE)},
               genotype={set.seed(106); sample(c(0,1,2), nsamp, replace=TRUE)})
}

test_runReg_linear <- function() {
    mod <- "outcome ~ covar + genotype"
    dat <- .regModelData(type="linear")
    tmp <- GWASTools:::.runRegression(mod, dat, "linear",
                                      CI=0.95, robust=FALSE, LRtest=FALSE)
    checkIdentical(names(tmp), c("Est", "SE", "LL", "UL", "Wald.Stat", "Wald.pval"))
    checkTrue(all(!is.na(tmp)))

    fit <- lm(as.formula(mod), data=dat)
    checkEquals(summary(fit)$coef["genotype",1:2], tmp[1:2], checkNames=FALSE)
}

test_runReg_logistic <- function() {
    mod <- "outcome ~ covar + genotype"
    dat <- .regModelData(type="logistic")
    tmp <- GWASTools:::.runRegression(mod, dat, "logistic",
                                      CI=0.95, robust=FALSE, LRtest=FALSE)
    checkIdentical(names(tmp), c("Est", "SE", "LL", "UL", "Wald.Stat", "Wald.pval"))
    checkTrue(all(!is.na(tmp)))

    fit <- glm(as.formula(mod), data=dat, family=binomial())
    checkEquals(summary(fit)$coef["genotype",1:2], tmp[1:2], checkNames=FALSE)
}

test_runReg_poisson <- function() {
    mod <- "outcome ~ covar + genotype"
    dat <- .regModelData(type="poisson")
    tmp <- GWASTools:::.runRegression(mod, dat, "poisson",
                                      CI=0.95, robust=FALSE, LRtest=FALSE)
    checkIdentical(names(tmp), c("Est", "SE", "LL", "UL", "Wald.Stat", "Wald.pval"))
    checkTrue(all(!is.na(tmp)))

    fit <- glm(as.formula(mod), data=dat, family=poisson())
    checkEquals(summary(fit)$coef["genotype",1:2], tmp[1:2], checkNames=FALSE)
}

test_runReg_CI <- function() {
    mod <- "outcome ~ covar + genotype"
    dat <- .regModelData(type="linear")
    tmp <- GWASTools:::.runRegression(mod, dat, "linear",
                                      CI=0.95, robust=FALSE, LRtest=FALSE)
    tmp2 <- GWASTools:::.runRegression(mod, dat, "linear",
                                       CI=0.90, robust=FALSE, LRtest=FALSE)
    checkTrue(tmp["LL"] < tmp2["LL"])
    checkTrue(tmp["UL"] > tmp2["UL"])
}

test_runReg_robust <- function() {
    library(sandwich)
    
    mod <- "outcome ~ covar + genotype"
    dat <- .regModelData(type="linear")
    tmp <- GWASTools:::.runRegression(mod, dat, "linear",
                                      CI=0.95, robust=TRUE, LRtest=FALSE)
    checkTrue(all(!is.na(tmp)))

    fit <- lm(as.formula(mod), data=dat)
    checkEquals(sqrt(vcovHC(fit, type="HC0")["genotype", "genotype"]),
                tmp[2], checkNames=FALSE)
}

test_runReg_LR <- function() {
    library(lmtest)
    
    mod <- "outcome ~ covar + genotype"
    dat <- .regModelData(type="linear")
    tmp <- GWASTools:::.runRegression(mod, dat, "linear",
                                      CI=0.95, robust=FALSE, LRtest=TRUE)
    checkIdentical(names(tmp), c("Est", "SE", "LL", "UL", "Wald.Stat", "Wald.pval",
                                 "LR.Stat", "LR.pval"))
    checkTrue(all(!is.na(tmp)))

    dat <<- dat
    fit <- lrtest(lm(as.formula(mod), data=dat), "genotype")
    checkEquals(unlist(fit[2, 4:5]), tmp[7:8], checkNames=FALSE)
}

test_runReg_GxE <- function() {
    mod <- "outcome ~ covar + covar:genotype + genotype"
    dat <- .regModelData(type="linear")
    tmp <- GWASTools:::.runRegression(mod, dat, "linear",
                                      CI=0.95, robust=FALSE, LRtest=FALSE)
    gxe.cols <- c("Est", "SE", "LL", "UL", "Wald.Stat", "Wald.pval",
                  "GxE.Est", "GxE.SE", "GxE.Stat", "GxE.pval",
                  "Joint.Stat", "Joint.pval")
    checkIdentical(names(tmp), gxe.cols)
    checkTrue(all(!is.na(tmp[c(1:6, 9:12)])))
    checkTrue(all(is.na(tmp[7:8]))) # covar has 3 levels

    fit <- lm(as.formula(mod), data=dat)
    gxe <- grep(":genotype", names(coef(fit)))
    x <- coef(fit)[gxe]
    checkEquals(as.numeric(t(x) %*% solve(vcov(fit)[gxe,gxe]) %*% x),
                tmp["GxE.Stat"], checkNames=FALSE)
    joint <- grep("genotype", names(coef(fit)))
    x <- coef(fit)[joint]
    checkEquals(as.numeric(t(x) %*% solve(vcov(fit)[joint,joint]) %*% x),
                tmp["Joint.Stat"], checkNames=FALSE)
    
    set.seed(107); dat$covar <- sample(letters[1:2], nrow(dat), replace=TRUE)
    tmp <- GWASTools:::.runRegression(mod, dat, "linear",
                                      CI=0.95, robust=FALSE, LRtest=FALSE)
    checkIdentical(names(tmp), gxe.cols)
    checkTrue(all(!is.na(tmp)))
   
    fit <- lm(as.formula(mod), data=dat)
    checkEquals(summary(fit)$coef[4,1:2] ,tmp[7:8], checkNames=FALSE)
}
    
test_runFirth <- function() {
    mod <- "outcome ~ covar + genotype"
    dat <- .regModelData()
    tmp <- GWASTools:::.runFirth(mod, dat, CI=0.95, PPLtest=FALSE)
    checkIdentical(names(tmp), c("Est", "SE", "LL", "UL", "Wald.Stat", "Wald.pval"))
    fm <- logistf(as.formula(mod), data=dat, pl=FALSE)
    checkEquals(tmp["Est"], coef(fm)["genotype"], checkNames=FALSE)
    checkEquals(tmp["LL"], fm$ci.lower["genotype"], checkNames=FALSE)
    checkEquals(tmp["UL"], fm$ci.upper["genotype"], checkNames=FALSE)
    checkEquals(tmp["Wald.pval"], fm$prob["genotype"], checkNames=FALSE)
    checkEquals(GWASTools:::.waldTest(tmp["Est"], (tmp["SE"])^2),
                tmp[c("Wald.Stat", "Wald.pval")], checkNames=FALSE)
}

test_runFirth_CI <- function() {
    mod <- "outcome ~ covar + genotype"
    dat <- .regModelData(type="linear")
    tmp <- GWASTools:::.runFirth(mod, dat, CI=0.95, PPLtest=FALSE)
    checkEquals(GWASTools:::.CI(tmp["Est"], tmp["SE"], 0.95),
                tmp[c("LL", "UL")], checkNames=FALSE)
    
    tmp2 <- GWASTools:::.runFirth(mod, dat, CI=0.90, PPLtest=FALSE)
    checkTrue(tmp["LL"] < tmp2["LL"])
    checkTrue(tmp["UL"] > tmp2["UL"])
}

test_runFirth_PPL <- function() {
    mod <- "outcome ~ covar + genotype"
    dat <- .regModelData()
    ind <- which(colnames(model.matrix(as.formula(mod), dat)) == "genotype")
    tmp <- GWASTools:::.runFirth(mod, dat, CI=0.95, PPLtest=TRUE, geno.index=ind)
    checkIdentical(names(tmp), c("Est", "SE", "LL", "UL", "Wald.Stat", "Wald.pval",
                                 "PPL.Stat", "PPL.pval"))
    fm <- logistf(as.formula(mod), data=dat, pl=TRUE, plconf=ind)
    checkEquals(tmp["Est"], coef(fm)["genotype"], checkNames=FALSE)
    checkEquals(tmp["LL"], fm$ci.lower["genotype"], checkNames=FALSE)
    checkEquals(tmp["UL"], fm$ci.upper["genotype"], checkNames=FALSE)
    checkEquals(tmp["PPL.pval"], fm$prob["genotype"], checkNames=FALSE)
}


.regGenoData <- function(nsnp=100, nsamp=50, chromosome=NULL) {
    if (is.null(chromosome)) {
        chromosome <- rep(c(1L,23L), each=nsnp/2)
    } else {
        chromosome <- rep(as.integer(chromosome), nsnp)
    }
    set.seed(108); geno <- matrix(sample(c(0,1,2,NA), nsnp*nsamp, replace=TRUE), nrow=nsnp, ncol=nsamp)
    geno[1,] <- 0 ## make one monomorphic
    mgr <- MatrixGenotypeReader(geno, snpID=1:nsnp, scanID=1:nsamp,
                                chromosome=chromosome,
                                position=1:nsnp)

    set.seed(109); sex <- sample(c("M","F"), nsamp, replace=TRUE)
    set.seed(110); age <- round(rnorm(nsamp, mean=40, sd=10))
    set.seed(111); site <- sample(letters[1:3], nsamp, replace=TRUE)
    set.seed(112); status <- rbinom(nsamp,1,0.4)
    set.seed(113); trait <- rnorm(nsamp, mean=10, sd=2)
    scanAnnot <- ScanAnnotationDataFrame(data.frame(scanID=1:nsamp,
      sex, age, site, status, trait))

    GenotypeData(mgr, scanAnnot=scanAnnot)
}

test_blocks <- function() {
    outcome <- "trait"
    model.type <- "linear"

    genoData <- .regGenoData()
    assoc1 <- assocRegression(genoData,
                          outcome = outcome,
                          model.type = model.type)
    assoc2 <- assocRegression(genoData,
                          outcome = outcome,
                          model.type = model.type,
                          block.size=33)
    checkEquals(assoc1, assoc2)
}

test_snps <- function() {
    outcome <- "trait"
    model.type <- "linear"

    genoData <- .regGenoData()
    assoc1 <- assocRegression(genoData,
                          outcome = outcome,
                          model.type = model.type)
    assoc2a <- assocRegression(genoData,
                          outcome = outcome,
                          model.type = model.type,
                          snpStart=1, snpEnd=50)
    assoc2b <- assocRegression(genoData,
                          outcome = outcome,
                          model.type = model.type,
                          snpStart=51, snpEnd=100)
    checkEquals(assoc1, rbind(assoc2a, assoc2b))
}


test_logistic <- function() {
    outcome <- "status"
    model.type <- "logistic"
    covar <- c("age","sex")

    genoData <- .regGenoData()
    set.seed(114); scan.exclude <- sample(getScanID(genoData), 10)

    assoc <- assocRegression(genoData,
                          outcome = outcome,
                          model.type = model.type,
                          covar = covar,
                          scan.exclude = scan.exclude)
    checkTrue(!all(is.na(assoc$Est)))
}

test_linear <- function() {
    outcome <- "trait"
    model.type <- "linear"
    covar <- c("age","sex")

    genoData <- .regGenoData()
    set.seed(115); scan.exclude <- sample(getScanID(genoData), 10)

    assoc <- assocRegression(genoData,
                          outcome = outcome,
                          model.type = model.type,
                          covar = covar,
                          scan.exclude = scan.exclude)
    checkTrue(!all(is.na(assoc$Est)))
}

test_GxE <- function() {
    outcome <- "trait"
    model.type <- "linear"
    covar <- c("age","sex")
    ivar <- "sex"

    genoData <- .regGenoData()

    assoc <- assocRegression(genoData,
                          outcome = outcome,
                          model.type = model.type,
                          covar = covar,
                          ivar = ivar)
    checkTrue(!all(is.na(assoc$Est)))
}

test_firth <- function() {
    outcome <- "status"
    model.type <- "firth"
    covar <- c("age","sex","site")
    PPLtest <- TRUE

    genoData <- .regGenoData()
    set.seed(116); scan.exclude <- sample(getScanID(genoData), 10)

    assoc <- assocRegression(genoData,
                          outcome = outcome,
                          model.type = model.type,
                          covar = covar,
                          scan.exclude = scan.exclude,
                          PPLtest = PPLtest)
    checkTrue(!all(is.na(assoc$Est)))
}

test_effectAllele <- function() {
    outcome <- "trait"
    model.type <- "linear"
    covar <- c("age","sex")

    genoData <- .regGenoData()
    assoc1 <- assocRegression(genoData,
                           outcome = outcome,
                           model.type = model.type,
                           covar = covar,
                           effectAllele="minor")
    checkEquals(assoc1$EAF, assoc1$MAF)
    
    assoc2 <- assocRegression(genoData,
                           outcome = outcome,
                           model.type = model.type,
                           covar = covar,
                           effectAllele="alleleA")
    checkTrue(all(assoc2$effect.allele == "A"))
    
    Bmin <- assoc2$EAF != assoc2$MAF
    checkEquals(assoc1$Est[Bmin], -assoc2$Est[Bmin])
    checkEquals(assoc1$Est[!Bmin], assoc2$Est[!Bmin])
}

test_Ychr <- function() {
    genoData <- .regGenoData(chromosome=25)
    scan.exclude <- getScanID(genoData)[getSex(genoData) == "F"]

    outcome <- "trait"
    model.type <- "linear"
    assoc1 <- assocRegression(genoData,
                    outcome = outcome,
                    model.type = model.type)
    assoc2 <- assocRegression(genoData,
                    outcome = outcome,
                    model.type = model.type,
                    scan.exclude=scan.exclude)
    checkEquals(assoc1, assoc2)

    checkException(assocRegression(genoData,
                    outcome = outcome, covar="sex",
                    model.type = model.type))
}

test_sampleSize <- function() {
    outcome <- "status"
    model.type <- "logistic"
    covar <- c("age","sex","site")

    genoData <- .regGenoData()
    set.seed(117); scan.exclude <- sample(getScanID(genoData), 10)

    assoc <- assocRegression(genoData,
                          outcome = outcome,
                          model.type = model.type,
                          covar = covar,
                          scan.exclude = scan.exclude)
    checkEquals(assoc$n, assoc$n0 + assoc$n1)
}
