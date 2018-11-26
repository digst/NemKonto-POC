package dk.digst.nemkonto.poc.devenvdemo.data;

import javax.annotation.Generated;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * En kontoejer, med tilhørende konto
 * @author Thomas Thorndahl (thomas@codecast.dk)
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
@Generated("org.jsonschema2pojo")
public class KontoEjer {

	private String _id;
	private String kontoejerID;
	private String kontoejertype;
	private String virksomhedssekundaerIdentifikation;
	private String virksomhedssekundaerIdentifikationstype;
	private int nksnummer;
	private Konto konto;

	public KontoEjer() { }
	
	public KontoEjer(String _id, String kontoejerID, String kontoejertype, String virksomhedssekundaerIdentifikation,
			String virksomhedssekundaerIdentifikationstype, int nksnummer, Konto konto) {
		this._id = _id;
		this.kontoejerID = kontoejerID;
		this.kontoejertype = kontoejertype;
		this.virksomhedssekundaerIdentifikation = virksomhedssekundaerIdentifikation;
		this.virksomhedssekundaerIdentifikationstype = virksomhedssekundaerIdentifikationstype;
		this.nksnummer = nksnummer;
		this.konto = konto;
	}
	@JsonProperty("kontoejerID")
	public String getKontoejerID() {
		return kontoejerID;
	}
	public void setKontoejerID(String kontoejerID) {
		this.kontoejerID = kontoejerID;
	}
	@JsonProperty("kontoejertype")
	public String getKontoejertype() {
		return kontoejertype;
	}
	public void setKontoejertype(String kontoejertype) {
		this.kontoejertype = kontoejertype;
	}
	@JsonProperty("virksomhedssekundaerIdentifikation")
	public String getVirksomhedssekundaerIdentifikation() {
		return virksomhedssekundaerIdentifikation;
	}
	public void setVirksomhedssekundaerIdentifikation(String virksomhedssekundaerIdentifikation) {
		this.virksomhedssekundaerIdentifikation = virksomhedssekundaerIdentifikation;
	}
	@JsonProperty("virksomhedssekundaerIdentifikationstype")
	public String getVirksomhedssekundaerIdentifikationstype() {
		return virksomhedssekundaerIdentifikationstype;
	}
	public void setVirksomhedssekundaerIdentifikationstype(String virksomhedssekundaerIdentifikationstype) {
		this.virksomhedssekundaerIdentifikationstype = virksomhedssekundaerIdentifikationstype;
	}
	@JsonProperty("nksnummer")
	public int getNksnummer() {
		return nksnummer;
	}
	public void setNksnummer(int nksnummer) {
		this.nksnummer = nksnummer;
	}
	@JsonProperty("konto")
	public Konto getKonto() {
		return konto;
	}
	public void setKonto(Konto konto) {
		this.konto = konto;
	}
	@JsonProperty("_id")
	public String get_id() {
		return _id;
	}
	public void set_id(String _id) {
		this._id = _id;
	}

}
