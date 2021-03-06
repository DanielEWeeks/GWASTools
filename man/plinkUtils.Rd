\name{plinkUtils}
\alias{plinkWrite}
\alias{plinkCheck}
\title{Utilities to create and check PLINK files}
\description{
\code{plinkWrite} creates ped and map format files (used by PLINK) from a \code{\link{GenotypeData}}
object.
\code{plinkCheck} checks whether a set of ped and map files has
identical data to a \code{\link{GenotypeData}} object.
}
\usage{
plinkWrite(genoData, pedFile="testPlink", family.col="family",
  individual.col="scanID", father.col="father", mother.col="mother",
  phenotype.col=NULL,
  rs.col="rsID", mapdist.col=NULL, scan.exclude=NULL,
  scan.chromosome.filter=NULL, blockSize=100, verbose=TRUE)

plinkCheck(genoData, pedFile, logFile="plinkCheck.txt", family.col="family",
  individual.col="scanID", father.col="father", mother.col="mother",
  phenotype.col=NULL,
  rs.col="rsID", map.alt=NULL, check.parents=TRUE, check.sex=TRUE,
  scan.exclude=NULL, scan.chromosome.filter=NULL, verbose=TRUE)
}
\arguments{
  \item{genoData}{A \code{\link{GenotypeData}} object with scan and SNP annotation.}
  \item{pedFile}{prefix for PLINK files (pedFile.ped, pedFile.map)}
  \item{logFile}{Name of the output file to log the results of \code{plinkCheck}}
  
  \item{family.col}{name of the column in the scan annotation that contains family ID of the sample}
  \item{individual.col}{name of the column in the scan annotation that contains individual ID of the sample}
  \item{father.col}{name of the column in the scan annotation that contains father ID of the sample}
  \item{mother.col}{name of the column in the scan annotation that contains mother ID of the sample}
  \item{phenotype.col}{name of the column in the scan annotation that
    contains phenotype variable (e.g. case control statue) of the sample}
  \item{rs.col}{name of the column in the SNP annotation that contains rs ID (or some other ID) for the SNP}
  \item{mapdist.col}{name of the column in the SNP annotation that
    contains genetic distance in Morgans for the SNP}
  \item{map.alt}{data frame with alternate SNP mapping for genoData to
  PLINK.  If not \code{NULL}, this annotation will be used to compare
  SNP information to the PLINK file, rather than the default conversion
  from the SNP annotation embedded in \code{genoData}.  Columns should
  include "snpID", "rsID", "chromosome", "position".}
  \item{check.parents}{logical for whether to check the father and
    mother columns}
  \item{check.sex}{logical for whether to check the sex column}
  \item{scan.exclude}{vector of scanIDs to exclude from PLINK file}

  \item{scan.chromosome.filter}{a logical matrix that can be used to
  zero out (set to missing) some chromosomes, some scans, or some specific scan-chromosome
  pairs. Entries should be \code{TRUE} if that scan-chromosome pair should have
  data in the PLINK file, \code{FALSE} if not. The number of rows must be
  equal to the number of scans in \code{genoData}.  The column labels must be
  in the set ("1":"22", "X", "XY", "Y", "M", "U").}
  
  \item{blockSize}{Number of samples to read from \code{genoData} at a
    time}
  \item{verbose}{logical for whether to show progress information.}
}
\details{
If "alleleA" and "alleleB" columns are not found in the SNP annotation
of \code{genoData}, genotypes are
written as "A A", "A B", "B B" (or "0 0" for missing data).

If \code{phenotype.col=NULL}, \code{plinkWrite} will use "-9"
for writing phenotype data and \code{plinkCheck} will omit checking this
column.

If \code{mapdist.col=NULL}, \code{plinkWrite} will use "0"
for writing this column in the map file and \code{plinkCheck} will omit checking this
column.

\code{plinkCheck} first reads the map file and checks for SNP
mismatches (chromosome, rsID, and/or position).  Any mismatches are
written to \code{logFile}.
\code{plinkCheck} then reads the ped file line by line, recording all
mismatches in \code{logFile}.
SNPs and sample order is not required to be the same as in \code{genoData}.
In the case of genotype mismatches, for each sample the log file output gives the
position of the first mismatched SNP in the PLINK file, as well as the
genotypes of the first six mismatched SNPs (which may not be consecutive).

These utilities convert between chromosome coding in
\code{\link{GenotypeData}}, which by default is 24=XY, 25=Y, and PLINK
chromosome coding, which is 24=Y, 25=XY.

Larger blockSize will improve speed but will require more RAM.
}
\value{
  \code{plinkCheck} returns \code{TRUE} if the PLINK files contain
  identical data to \code{genoData}, and \code{FALSE} if a mismatch is encountered.
}
\references{
Please see
  \url{http://pngu.mgh.harvard.edu/~purcell/plink/data.shtml#ped} for
  more information on the ped and map files. 
}
\author{Stephanie Gogarten, Tushar Bhangale}
\seealso{\code{\link[SNPRelate]{snpgdsBED2GDS}}}
\examples{
library(GWASdata)
ncfile <- system.file("extdata", "illumina_geno.nc", package="GWASdata")
data(illuminaSnpADF, illuminaScanADF)
genoData <- GenotypeData(NcdfGenotypeReader(ncfile),
  scanAnnot=illuminaScanADF, snpAnnot=illuminaSnpADF)

pedfile <- tempfile()
plinkWrite(genoData, pedfile)
logfile <- tempfile()
plinkCheck(genoData, pedfile, logfile)

# exclude samples
plinkWrite(genoData, pedfile, scan.exclude=c(281, 283),
  blockSize=10)
plinkCheck(genoData, pedfile, logfile)
readLines(logfile)
#samples not found in Ped:
#281
#283

close(genoData)
unlink(c(logfile, paste(pedfile, "*", sep=".")))
}
\keyword{manip}
