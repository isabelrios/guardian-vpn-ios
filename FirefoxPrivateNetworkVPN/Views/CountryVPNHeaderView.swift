//
//  CountryVPNHeaderView
//  FirefoxPrivateNetworkVPN
//
//  Copyright © 2019 Mozilla Corporation. All rights reserved.
//

import UIKit
import RxSwift

class CountryVPNHeaderView: UITableViewHeaderFooterView {
    static let height: CGFloat = 56.0

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var flagImageView: UIImageView!
    @IBOutlet weak var chevronImageView: UIImageView!
    @IBOutlet weak var topLineView: UIView!

    weak var tapPublishSubject: PublishSubject<CountryVPNHeaderView>?

    var isExpanded: Bool = false {
        willSet {
            DispatchQueue.main.async { [weak self] in
                self?.chevronImageView.image = newValue ? #imageLiteral(resourceName: "icon_sectionOpen") : #imageLiteral(resourceName: "icon_sectionClosed")
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        setupTaps()
    }

    func setup(country: VPNCountry) {
        flagImageView.image = UIImage(named: "flag_\(country.code.lowercased())")
        nameLabel.text = country.name
        topLineView.isHidden = tag == 0
    }

    @objc private func handleTap(sender: UITapGestureRecognizer) {
        tapPublishSubject?.onNext(self)
    }

    private func setupTaps() {
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(sender:)))
        addGestureRecognizer(tapRecognizer)
    }
}