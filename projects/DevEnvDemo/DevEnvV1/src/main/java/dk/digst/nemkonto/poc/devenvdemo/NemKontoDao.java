package dk.digst.nemkonto.poc.devenvdemo;

import java.util.Iterator;

import org.ojai.DocumentStream;

import com.mapr.db.Condition.Op;
import com.mapr.db.DBDocument;
import com.mapr.db.MapRDB;
import com.mapr.db.Table;

import dk.digst.nemkonto.poc.devenvdemo.data.BaseDataSet;
import dk.digst.nemkonto.poc.devenvdemo.data.KontoEjer;

/**
 * Dataadgang for webservices. 
 * @author Thomas Thorndahl (thomas@codecast.dk)
 */
public class NemKontoDao {

	/**
	 * Database table for POC sample data. Hvis denne ændres skal createBaseData() kaldes på ny
	 */
	private static final String TABLE = "/tmp/nemkontopoc";

	private static final NemKontoDao INSTANCE = new NemKontoDao();
	
	/**
	 * @return Singleton-instans af DAO
	 */
	public static NemKontoDao getInstance() {
		return INSTANCE;
	}
	
	private NemKontoDao() { }
	
	/**
	 * Opret {@link KontoEjer}
	 * @param Kontoejer. Kontoejerid anvendes som ID på record
	 */
	public void create(KontoEjer k) {
		Table t = MapRDB.getTable(TABLE);
		DBDocument o = MapRDB.newDocument(k);
		t.insert(k.getKontoejerID(), o);
	}

	/**
	 * Finder {@link KontoEjer} ud fra kontonummer
	 * @param registreringsnummer Normalt 4 cifret talkode
	 * @param kontonummer Talkode, indledende 0-taller skal angives, hvis de er angives ved oprettelsen
	 * @param kontoejertype <u>Person</u> eller <u>Virksomhed</u>
	 * @return KontoEjer eller null hvis ingen findes for angivne søgekriterier
	 */
	public KontoEjer findFromRegAccount(String registreringsnummer, String kontonummer, String kontoejertype) {
		Table t = MapRDB.getTable(TABLE);
		DocumentStream<DBDocument> s = t.find(
			MapRDB.newCondition().and()
				.is("konto.registreringsnummer", Op.EQUAL, registreringsnummer)
				.is("konto.kontonummer", Op.EQUAL, kontonummer)
				.is("kontoejertype", Op.EQUAL, kontoejertype).close().build()
		);
		KontoEjer e;
		
		Iterator<DBDocument> it = s.iterator();
		if (it.hasNext()) {
			DBDocument doc = it.next();
			// HACK: JavaBean indeholder ikke nogle data ud over ID, hvis der ikke kaldes get() på en 
			//       attribut inden at DBDocument konverteres til JavaBean
			doc.getString("kontoejertype");
			e = doc.toJavaBean(KontoEjer.class);
		}
		else {
			e = null;
		}
		return e;
	}
	
	/**
	 * Finder {@link KontoEjer} fra ID
	 * @param id CPR eller CVR nr. på kontoejer
	 * @param kontoejertype <u>Person</u> eller <u>Virksomhed</u>
	 * @return {@link KontoEjer}, eller null hvis ingen fundet ud fra søgekriterier
	 */
	public KontoEjer findFromId(String id, String kontoejertype) {
		Table t = MapRDB.getTable(TABLE);
		DocumentStream<DBDocument> s = t.find(
			MapRDB.newCondition().and().is("_id", Op.EQUAL, id).is("kontoejertype", Op.EQUAL, kontoejertype).close().build()
		);
		KontoEjer e;
		
		Iterator<DBDocument> it = s.iterator();
		if (it.hasNext()) {
			DBDocument doc = it.next();
			// HACK: JavaBean indeholder ikke nogle data ud over ID, hvis der ikke kaldes get() på en 
			//       attribut inden at DBDocument konverteres til JavaBean
			doc.getString("kontoejertype");
			e = doc.toJavaBean(KontoEjer.class);
		}
		else {
			e = null;
		}
		return e;
	}

	/**
	 * Opretter sample data baseret på {@link KontoEjer} typer som defineret i {@link BaseDataSet}
	 */
	public void createBasedata() {
		if (MapRDB.tableExists(TABLE)) {
			MapRDB.deleteTable(TABLE);
		}
		MapRDB.createTable(TABLE);
		for (KontoEjer k : BaseDataSet.KONTOEJERE) {
			create(k);
		}
	}
}
