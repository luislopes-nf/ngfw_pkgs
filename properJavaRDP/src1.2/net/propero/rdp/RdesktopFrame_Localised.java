/* RdesktopFrame_Localised.java
 * Component: ProperJavaRDP
 * 
 * Revision: $Revision: 1.7 $
 * Author: $Author: telliott $
 * Date: $Date: 2005/09/27 14:15:38 $
 *
 * Copyright (c) 2005 Propero Limited
 *
 * Purpose: Java 1.2 specific extension of RdesktopFrame class
 */
// Created on 07-Jul-2003

package net.propero.rdp;

public class RdesktopFrame_Localised extends RdesktopFrame {
	protected void checkFullScreenWidthHeight(){
		if(Options.fullscreen){
		//	can't remove frame decoration so reduce size to compensate
			Options.height -= 26;
			Options.width -= 8;
		}
	}
}


