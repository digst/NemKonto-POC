package dk.digst.nemkonto.poc.devenvdemo.data;

import java.util.Date;

import javax.annotation.Generated;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Konto, en NemKonto med tilhørende adresse
 * @author Thomas Thorndahl (thomas@codecast.dk)
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
@Generated("org.jsonschema2pojo")
public final class Konto {
	
	private String valutakode;
	private String kontonummer;
	private String kontotype;
	private String kontoejerNavn;
	private String registreringsnummer;
	private String pengeinstitutNavn;
	private String pengeinstitutType;
	private String iban;
	private String SWIFTkode;
	private Date slutdato;
	private Date startdato;
	private Adresse konteringsadresse;
	
	public Konto() { }
	
	public Konto(String valutakode, String kontonummer, String kontotype, String kontoejerNavn,
			String registreringsnummer, String pengeinstitutNavn, String pengeinstitutType, String iban,
			String SWIFTkode, Date slutdato, Date startdato, Adresse konteringsadresse) {
		this.valutakode = valutakode;
		this.kontonummer = kontonummer;
		this.kontotype = kontotype;
		this.kontoejerNavn = kontoejerNavn;
		this.registreringsnummer = registreringsnummer;
		this.pengeinstitutNavn = pengeinstitutNavn;
		this.pengeinstitutType = pengeinstitutType;
		this.iban = iban;
		this.SWIFTkode = SWIFTkode;
		this.slutdato = slutdato;
		this.startdato = startdato;
		this.konteringsadresse = konteringsadresse;
	}
	@JsonProperty("valutakode")
	public String getValutakode() {
		return valutakode;
	}
	public void setValutakode(String valutakode) {
		this.valutakode = valutakode;
	}
	@JsonProperty("kontonummer")
	public String getKontonummer() {
		return kontonummer;
	}
	public void setKontonummer(String kontonummer) {
		this.kontonummer = kontonummer;
	}
	@JsonProperty("kontotype")
	public String getKontotype() {
		return kontotype;
	}
	public void setKontotype(String kontotype) {
		this.kontotype = kontotype;
	}
	@JsonProperty("kontoejerNavn")
	public String getKontoejerNavn() {
		return kontoejerNavn;
	}
	public void setKontoejerNavn(String kontoejerNavn) {
		this.kontoejerNavn = kontoejerNavn;
	}
	@JsonProperty("registreringsnummer")
	public String getRegistreringsnummer() {
		return registreringsnummer;
	}
	public void setRegistreringsnummer(String registreringsnummer) {
		this.registreringsnummer = registreringsnummer;
	}
	@JsonProperty("pengeinstitutNavn")
	public String getPengeinstitutNavn() {
		return pengeinstitutNavn;
	}
	public void setPengeinstitutNavn(String pengeinstitutNavn) {
		this.pengeinstitutNavn = pengeinstitutNavn;
	}
	@JsonProperty("pengeinstitutType")
	public String getPengeinstitutType() {
		return pengeinstitutType;
	}
	public void setPengeinstitutType(String pengeinstitutType) {
		this.pengeinstitutType = pengeinstitutType;
	}
	@JsonProperty("iban")
	public String getIban() {
		return iban;
	}
	public void setIban(String iban) {
		this.iban = iban;
	}
	@JsonProperty("SWIFTkode")
	public String getSWIFTkode() {
		return SWIFTkode;
	}
	public void setSWIFTkode(String SWIFTkode) {
		this.SWIFTkode = SWIFTkode;
	}
	@JsonProperty("slutdato")
	public Date getSlutdato() {
		return slutdato;
	}
	public void setSlutdato(Date slutdato) {
		this.slutdato = slutdato;
	}
	@JsonProperty("startdato")
	public Date getStartdato() {
		return startdato;
	}
	public void setStartdato(Date startdato) {
		this.startdato = startdato;
	}
	@JsonProperty("konteringsadresse")
	public Adresse getKonteringsadresse() {
		return konteringsadresse;
	}
	public void setKonteringsadresse(Adresse konteringsadresse) {
		this.konteringsadresse = konteringsadresse;
	}

}
