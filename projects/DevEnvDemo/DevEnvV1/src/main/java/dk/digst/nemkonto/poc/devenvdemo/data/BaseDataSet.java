package dk.digst.nemkonto.poc.devenvdemo.data;

import java.text.DateFormat;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Date;

/**
 * 
 * @author ThomasThorndahl
 *
 */
public class BaseDataSet {

	private static final DateFormat DATE_FORMATTER = new SimpleDateFormat("yyyy-MM-dd");

	private BaseDataSet() { }

	private static Date date(String date) {
		try {
			return DATE_FORMATTER.parse(date);
		} catch (ParseException e) {
			e.printStackTrace();
			return null;
		}
	}

	/**
	 * KontoEjere, til anvendelse ved indsættelse af sample data
	 */
	public static final KontoEjer[] KONTOEJERE = {
		new KontoEjer("1104781235", "1104781235","Person", "", "", 50506060, new Konto("DKK", "4811223344", "Generel", 
			"Jens Peter Kontoejer", "1020", "Nordea Bank", "DK", "DK10204811223344", "DKSEDKMM", date("2019-04-01"), date("2017-05-01"), 
			new Adresse("Danmark", "Gammel Kongevej 1", "2000", "Frederiksberg", "Kontoejer")
		)),
		new KontoEjer("0411875321", "0411875321","Person", "", "", 60607070, new Konto("DKK", "7535949621", "Generel", 
			"Hans Ole Kontoejer", "5122", "Danske Bank A/S", "DK", "DK51227535949621", "DKRNDKNN", date("2021-02-15"), date("2015-04-01"), 
			new Adresse("Danmark", "Roskildevej 147", "3600", "Frederikssund", "Kontoejer")
		)),
		new KontoEjer("32080808", "32080808","Virksomhed", "15151616", "P-nummer", 20203030, new Konto("DKK", "1151512929", "Generel", 
			"Maribo Seed A/S", "5454", "Nordea Bank", "DK", "DK54541151512929", "DKHHYTYT", date("2019-04-01"), date("2017-05-01"), 
			new Adresse("Danmark", "Gammel Kongevej 1", "2000", "Frederiksberg", "Kontoejer")
		)),
		new KontoEjer("34050505", "34050505","Virksomhed", "21210505", "P-nummer", 20554055, new Konto("DKK", "7899332255", "Generel", 
			"Elgiganten", "4421", "Danske Bank A/S", "DK", "DK44217899332255", "DKRNDKNN", date("2027-01-01"), date("2011-02-15"), 
			new Adresse("Danmark", "Roskildevej 147", "3600", "Frederikssund", "Kontoejer")
		))
	};
}
