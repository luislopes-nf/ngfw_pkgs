/* ScreenBltOrder.java
 * Component: ProperJavaRDP
 * 
 * Revision: $Revision: 1.7 $
 * Author: $Author: telliott $
 * Date: $Date: 2005/09/27 14:15:40 $
 *
 * Copyright (c) 2005 Propero Limited
 *
 * Purpose: 
 */
package net.propero.rdp.orders;

public class ScreenBltOrder extends DestBltOrder {

    private int srcx = 0;
    private int srcy = 0;

    public ScreenBltOrder() {
	super();
    }

    public int getSrcX() {
	return this.srcx;
    }
    
    public int getSrcY() {
	return this.srcy;
    }

    public void setSrcX(int srcx) {
	this.srcx = srcx;
    }

    public void setSrcY(int srcy) {
	this.srcy = srcy;
    }

    public void reset() {
	super.reset();
	srcx = 0;
	srcy = 0;
    }
}
