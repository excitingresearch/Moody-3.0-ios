//
//  TableViewCell.swift
//  Moody
//
//  Created by Nassim Versbraegen on 19/08/2022.
//

import Foundation


import UIKit

class TableViewCell: UITableViewCell {

    @IBOutlet weak var peripheralLabel: UILabel!
    @IBOutlet weak var rssiLabel: UILabel!



    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
