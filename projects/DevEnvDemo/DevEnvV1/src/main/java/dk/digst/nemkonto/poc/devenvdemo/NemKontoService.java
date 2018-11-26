package dk.digst.nemkonto.poc.devenvdemo;

import dk.digst.nemkonto.poc.devenvdemo.data.KontoEjer;

/**
 * Tjenester, som skal udstilles som webservices
 * @author Thomas Thorndahl (thomas@codecast.dk)
 */
public class NemKontoService {

	public boolean hasNemKontoFromID(String id, String accounttype) {
		return getNemKontoFromID(id, accounttype) != null;
	}
	
	public KontoEjer getIDFromNemKonto(String regno, String accountno, String accounttype) {
		KontoEjer ke;
		if (regno != null && !regno.isEmpty() && accountno != null && !accountno.isEmpty()) {
			KontoEjer k = NemKontoDao.getInstance().findFromRegAccount(regno, accountno, accounttype);
			if (k != null ) {
				ke = k;
			}
			else {
				ke = null;
			}
		}
		else {
			ke = null;
		}
		return ke;
	}
	
	public KontoEjer getNemKontoFromID(String id, String accounttype) {
		KontoEjer ke;
		if (id != null && !id.isEmpty() && accounttype != null && !accounttype.isEmpty()) {
			KontoEjer k = NemKontoDao.getInstance().findFromId(id, accounttype);
			if (k != null ) {
				ke = k;
			}
			else {
				ke = null;
			}
		}
		else {
			ke = null;
		}
		return ke;
	}
	
	public void configureBaseData() {
		NemKontoDao.getInstance().createBasedata();
	}
}
