#' Create a simple graphical report of the most important SCC indicators
#'
#' This function calculates the most important udder health indicators that are
#' based on the monthly dairy herd improvement test somatic cell counts (SCC)
#' according to the DLQ and \url{http://www.milchqplus.de} and produces a concise
#' graphical report on a single page in pdf-format.  
#' The indicators are calculated for the 13 recent months for which data is provided.  
#'
#' @param inputFile Character of length 1. Full path to the data file to be used for monitoring.
#' @param inputType Character of length 1. One of \code{c("adis", "herde")}.
#' @param Farm A character string, the 'name' used for the herd / farm in the report.
#' @param out_dir Optional character of length 1. Full path to the directory where the report
#'  file should be produced. If not specified the directory of \code{inputFile} is used.
#' @param out_window Logical of length 1. Should the report be shown in the standard plot display?
#'  (Default is \code{FALSE})
#' @param return_results Logical of length 1. Should the data shown in the report be returned
#'  as a data.frame? (Default is \code{FALSE}).
#'
#' @details See \code{\link{prepare_PCstart}} for the required ADIS input file
#'   and \code{\link{prepare_HerdeMLP}} for the required input file from a HERDE backup  
#'   The definitions of the indicators are given in the package vignette
#'   \file{UdderHealthMonitor::User Guide}.
#'
#' @return A grafical report in pdf-format is always produced in the \code{out_dir}
#'  directory. If \env{return_results = TRUE}, the calculated values of the indicators
#'  are also returned as a data.frame with one row per month and the columns:
#'  \describe{
#' 	 \item{\code{Month}}{Test month}
#'   \item{\code{LowSCC}}{Percentage of cows without mastitis}
#'   \item{\code{LactNI}}{Lactational new infection rate}
#'   \item{\code{LactCure}}{Lactational cure rate}
#'   \item{\code{Chronic}}{Percentage of cows with chronic mastitis}
#'   \item{\code{NoCure}}{Percentage of cows with low chances of cure}
#'   \item{\code{DryNI}}{Dry period new infection rate}
#'   \item{\code{DryCure}}{Dry period cure rate}
#'   \item{\code{HeiferMast}}{Heifer mastitis rate}
#'  }
#'  \code{NULL} invisible otherwise.
#'
#' @references Visit \url{http://www.milchqplus.de} for further descriptions
#'  of the udder health indicators.
#' @references Have a look at \cite{V. Zoche, W. Heuwieser, and V. Kroemker, "Risk-based monitoring of udder health. A review."}, \href{http://www.schattauer.de/t3page/1214.html?manuscript=16040}{Tierärztliche Praxis. Ausgabe G, Grosstiere/Nutztiere, vol. 39, no. 2, pp. 88–94, 2011.} and \href{http://www.lkvsachsen.de/fileadmin/lkv/redaktion/download/unternehmen/Veredlungsland/Handout_Euterschulung.pdf}{these slides} for information about monitoring the udder health.
#'
#' @note Currently different 'AE's are ignored and all animals of one herd are analysed together.
#'
#' @importFrom magrittr '%>%'
#'
#' @export

IndicatorSheet <- function(
		inputFile = NULL,
		inputType = "adis",
		Farm = "SomeDairyHerd",
		out_dir = NULL,
		out_window = FALSE,
		return_results = FALSE
) {
	
	# test the parameters
	
	if (is.null(inputFile)) {
		
		inputFile <- try(file.choose())
		
		if ("try-error" %in% class(inputFile)) {
			
			cat("\nNo inputFile file selected.\n")
			
			return(invisible(NULL))
			
		}
		
	}
	assertive::assert_is_of_length(inputFile, 1)
	
	
	assertive::assert_is_of_length(inputType, 1)
	assertive::assert_is_subset(inputType, c("adis", "herde"))
	
	
	if (is.null(out_dir)) {
		
		out_dir <- dirname(inputFile)
		
	}
	assertive::assert_is_of_length(out_dir, 1)
	assertive::assert_all_are_dirs(out_dir)
	
	
	assertive::assert_is_of_length(out_window, 1)
	assertive::assert_is_logical(out_window)
	
	
	assertive::assert_is_of_length(Farm, 1)
	assertive::assert_is_character(Farm)
	
	
	assertive::assert_is_of_length(return_results, 1)
	assertive::assert_is_logical(return_results)
	
	
	
	
	# import data
	
	CowData <- switch(
			inputType,
			adis = prepare_PCstart(inputFile)$einzeltiere,
			herde = prepare_HerdeMLP(inputFile),
			stop("Unkown inputType!")
	)
	
	
	
	
	# Calculate indicators per month for the 13 recent months with available data
	
	monthsToShow <- 13
	dataMonths <- seq(max(CowData$Pruefdatum), by = "-1 month", length.out = monthsToShow)
	
	indicators <- data.frame(
			Month = numeric(0),
			value = numeric(0),
			indicator = character(0),
			period = character(0),
			stringsAsFactors = FALSE
	)
	for (p in c("Lactation", "Dry Period")) {
		
		if (p == "Lactation") {
			
			inds <- c("LowSCC", "LactNI", "LactCure", "Chronic", "NoCure")
			
		} else {
			
			inds <- c("DryNI", "DryCure", "HeiferMast")
			
		}
		
		for (i in inds) {
			
			indicatorI <- calculate_indicator(i, data = CowData, testmonths = dataMonths)
			
			indicators <- rbind(
					indicators,
					data.frame(
							Month = indicatorI$Month,
							value = indicatorI$c,
							indicator = rep(i, monthsToShow),
							period = rep(p, monthsToShow),
							stringsAsFactors = FALSE
					)
			)
			
		}
		
	}
	
	
	
	
	# plot indicators
	
	i2 <- indicators
	i2$in2 <- factor(i2$indicator, levels = unique(i2$indicator), labels = "i")
	i2$idx <- rep(monthsToShow:1, 8)
	
	indPlot <- lattice::xyplot(
			value ~ idx | period,
			groups = in2,
			data = i2,
			main = "UdderHealthMonitor-IndicatorSheet",
			sub = paste(Farm, Sys.Date(), sep = "; created: "),
			xlab = "Month",
			scales = list(
					x = list(
							cex = 1,
							at = seq(1, monthsToShow, 2),
							labels = substr(as.character(i2$Month[seq(monthsToShow, 1, -2)]), 1, 7),
							rot = 45
					)
			),
			ylab = "%",
			strip = FALSE,
			strip.left = TRUE,
			type = c("g", "b"),
			layout = c(1, 2),
			between = list(
					x = 0,
					y = 0.2
			),
			par.settings = simpleTheme(
					lwd = 1.5,
					lty = c(1, 2, 3, 4, 6, 2, 3, 5),
					pch = c(13, 1, 0, 5, 6, 16, 15, 17)
			),
			auto.key = list(
					text = c(
							"Percentage of cows without mastitis",
							"Lactational new infection rate",
							"Lactational cure rate",
							"Percentage of cows with chronic mastitis",
							"Percentage of cows with low chances of cure",
							"Dry period new infection rate",
							"Dry period cure rate",
							"Heifer mastitis rate"
					),
					points = FALSE,
					lines = TRUE,
					cex = 0.6,
					type = "b",
					divide = 1,
					columns = 4)
	)
	
	if (out_window == TRUE) print(indPlot)
	
	lattice::trellis.device(
			device = "pdf",
			title = "UdderHealthMonitor-IndicatorSheet",
			width = 11,
			height = 7.5,
			paper = "a4r",
			color = FALSE,
			file = paste(out_dir, "/IndicatorSheet_", Farm, "_", Sys.Date(), ".pdf", sep = "")
	)
	on.exit(dev.off())
	print(indPlot)
	message(paste(
					"The report was produced as '",
					"IndicatorSheet_", Farm, "_", Sys.Date(), ".pdf'",
					" in '", out_dir, "'.",
					sep = ""
			))
	
	
	
	
	# return results
	
	if (return_results == TRUE) {
		
		out <- matrix(
						indicators$value,
						nrow = monthsToShow,
						ncol = 8,
						dimnames = list(
								NULL,
								unique(indicators$indicator)
						)
				) %>%
				as.data.frame
		out <- cbind(
				Month = indicators$Month[1:monthsToShow],
				out
		)
		out$Month <- as.character(out$Month)
		return(out)
		
	} else {
		
		invisible(NULL)
		
	}
	
}